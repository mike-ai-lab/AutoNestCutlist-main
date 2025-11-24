require 'set'
require_relative '../models/part' # Ensure the Part class is loaded
require_relative '../util' # Ensure Util module is loaded

module AutoNestCut
  class ModelAnalyzer

    def initialize
      @selected_entities = []
      @original_components = []
      @hierarchy_tree = []
      @processed_entities = Set.new
      @progress_callback = nil
    end

    def analyze_selection(selection, progress_callback = nil)
      @selected_entities = selection.to_a
      @original_components = [] # Reset for a fresh analysis
      @hierarchy_tree = [] # Reset for a fresh analysis
      @processed_entities = Set.new # Reset processed entities for a fresh analysis
      @progress_callback = progress_callback
      
      total_entities = @selected_entities.length

      # Initialize definition_counts here so it's accessible throughout this method
      definition_counts = Hash.new(0) # <-- CRITICAL FIX: Initialize here

      # Build hierarchy tree first (simplified version for now)
      # Building hierarchy can involve creating Part objects to get material data
      @hierarchy_tree = @selected_entities.map { |entity| build_simple_tree(entity, 0) }.compact


      # AGGRESSIVE RECURSIVE SEARCH through ALL levels with batching
      @selected_entities.each_with_index do |entity, index|
        if @progress_callback
          progress = 30 + (index.to_f / total_entities * 50).round(1)
          @progress_callback.call("Analyzing components... #{index + 1}/#{total_entities}", progress)
        end
        
        deep_recursive_search(entity, definition_counts, Geom::Transformation.new) # Pass the now-accessible definition_counts
        
        # Micro-sleep every 5 entities for responsiveness
        sleep(0.002) if index % 5 == 0
      end

      part_types_by_material = {}
      definition_count = definition_counts.length # This will now be correctly accessed
      processed_definitions = 0

      # Process only sheet goods and batch create parts
      definition_counts.each do |definition, total_count_for_type|
        processed_definitions += 1
        
        if @progress_callback
          progress = 80 + (processed_definitions.to_f / definition_count * 20).round(1)
          @progress_callback.call("Creating part types... #{processed_definitions}/#{definition_count}", progress)
        end
        
        # Pass definition to Part constructor. Part is now responsible for determining its material.
        # Ensure Part is initialized with a ComponentDefinition for this step
        part_type = AutoNestCut::Part.new(definition) 
        
        if Util.is_sheet_good?(definition.bounds)
          material_name = part_type.material # Get the material name from the created Part object
          part_types_by_material[material_name] ||= []
          part_types_by_material[material_name] << { part_type: part_type, total_quantity: total_count_for_type }
        end
        
        # Micro-sleep every few definitions
        sleep(0.001) if processed_definitions % 3 == 0
      end

      part_types_by_material
    end

    def get_original_components_data
      @original_components || []
    end
    
    def get_hierarchy_tree
      @hierarchy_tree || []
    end

    private

    # AGGRESSIVE DEEP RECURSIVE SEARCH - Goes through ALL nesting levels
    def deep_recursive_search(entity, definition_counts, transformation = Geom::Transformation.new)
      # For component instances, ensure we process its definition entities
      if entity.is_a?(Sketchup::ComponentInstance)
        # Count instances
        definition_counts[entity.definition] ||= 0
        definition_counts[entity.definition] += 1
        
        # Collect original components (only for sheet goods)
        bounds = entity.definition.bounds
        if Util.is_sheet_good?(bounds)
          combined_transform = transformation * entity.transformation
          
          # Use Part class to get consistent dimensions and material
          part_temp = AutoNestCut::Part.new(entity) # Pass the instance so instance material is checked first
          
          @original_components << {
            name: entity.definition.name,
            entity_id: entity.entityID,
            definition_id: entity.definition.entityID,
            width: part_temp.width.round(2), # Use Part object's dimensions
            height: part_temp.height.round(2), 
            depth: part_temp.thickness.round(2), # Changed to thickness
            position: {
              x: (combined_transform.origin.x * 25.4).round(2), # SketchUp reports in inches, convert to mm for UI
              y: (combined_transform.origin.y * 25.4).round(2),
              z: (combined_transform.origin.z * 25.4).round(2)
            },
            material: part_temp.material # Use Part object's material
          }
        end
        
        # SEARCH INSIDE COMPONENT DEFINITION (its entities)
        component_transform = transformation * entity.transformation
        entity.definition.entities.each { |child| deep_recursive_search(child, definition_counts, component_transform) }
        
      elsif entity.is_a?(Sketchup::Group)
        # SEARCH INSIDE GROUP
        group_transform = transformation * entity.transformation
        entity.entities.each { |child| deep_recursive_search(child, definition_counts, group_transform) }
      end
    end
    
    # Simple tree builder that always creates nodes 
    def build_simple_tree(entity, level)
      if entity.is_a?(Sketchup::ComponentInstance)
        # Use Part constructor for consistency in getting material and dimensions
        part_temp = AutoNestCut::Part.new(entity) # Pass the instance for more accurate material detection
        
        {
          type: 'component',
          name: entity.definition.name || 'Unnamed Component',
          level: level,
          material: part_temp.material, # Direct material lookup
          dimensions: "#{part_temp.width.round(1)}×#{part_temp.height.round(1)}×#{part_temp.thickness.round(1)}mm", # Use thickness
          children: []
        }
      elsif entity.is_a?(Sketchup::Group)
        children = []
        entity.entities.each do |child|
          if child.is_a?(Sketchup::ComponentInstance) || child.is_a?(Sketchup::Group)
            child_node = build_simple_tree(child, level + 1)
            children << child_node if child_node
          end
        end
        
        {
          type: 'group',
          name: entity.name || "Group_#{entity.entityID}",
          level: level,
          material: 'Container', # Groups don't typically have "material" like parts
          dimensions: '',
          children: children
        }
      else
        nil
      end
    end
    
    # build_hierarchy_tree is not currently used by analyze_selection, but updated for consistency
    def build_hierarchy_tree(entity, level)
      if entity.is_a?(Sketchup::ComponentInstance)
        children = []
        entity.definition.entities.each do |child|
          child_node = build_hierarchy_tree(child, level + 1)
          children << child_node if child_node
        end
        
        bounds = entity.definition.bounds
        part_temp = AutoNestCut::Part.new(entity) # Pass the instance for more accurate material detection

        if Util.is_sheet_good?(bounds)
          {
            type: 'component',
            name: entity.definition.name || 'Unnamed Component',
            level: level,
            material: part_temp.material,
            dimensions: "#{part_temp.width.round(1)}×#{part_temp.height.round(1)}×#{part_temp.thickness.round(1)}mm", # Use thickness
            children: children
          }
        elsif children.any?
          {
            type: 'component',
            name: entity.definition.name || 'Assembly',
            level: level,
            material: 'Assembly',
            dimensions: '',
            children: children
          }
        else
          nil
        end
      elsif entity.is_a?(Sketchup::Group)
        children = []
        entity.entities.each do |child|
          child_node = build_hierarchy_tree(child, level + 1)
          children << child_node if child_node
        end
        
        {
          type: 'group',
          name: entity.name || "Group_#{entity.entityID}",
          level: level,
          material: 'Container',
          dimensions: '',
          children: children
        }
      else
        nil
      end
    end
  end
end
