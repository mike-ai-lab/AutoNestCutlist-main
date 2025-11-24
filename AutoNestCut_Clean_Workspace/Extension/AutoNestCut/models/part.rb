require_relative '../util' # Ensure Util module is loaded for get_dimensions and get_dominant_material

module AutoNestCut
  class Part
    attr_accessor :name, :width, :height, :thickness, :material, :grain_direction, :edge_banding
    attr_reader :original_definition
    attr_accessor :x, :y, :rotated, :instance_id
    attr_accessor :texture_data # Ensure texture_data is accessible

    # Constructor now expects a component_definition_or_instance and optionally a specific Sketchup::Material object
    # or material_name string.
    def initialize(component_definition_or_instance, specific_material = nil)
      
      # Determine if we're initialized with a ComponentDefinition or ComponentInstance
      if component_definition_or_instance.is_a?(Sketchup::ComponentDefinition)
        @original_definition = component_definition_or_instance
        definition = component_definition_or_instance
        instance_material = nil # No instance material if starting from definition
      elsif component_definition_or_instance.is_a?(Sketchup::ComponentInstance)
        @original_definition = component_definition_or_instance.definition
        definition = component_definition_or_instance.definition
        instance_material = component_definition_or_instance.material # Material assigned to instance
      else
        raise ArgumentError, "Part must be initialized with a Sketchup::ComponentDefinition or Sketchup::ComponentInstance"
      end

      @name = definition.name

      dimensions_mm = Util.get_dimensions(definition.bounds).sort
      @thickness = dimensions_mm[0]
      @width = dimensions_mm[1]
      @height = dimensions_mm[2]

      # --- CRITICAL FIXES FOR MATERIAL/GRAIN/EDGE BANDING ---
      # Prioritize material in this order: specific_material (if passed) > instance material > definition material > dominant face material > 'No Material'
      detected_material = nil
      if specific_material.is_a?(Sketchup::Material)
        detected_material = specific_material.display_name || specific_material.name
      elsif specific_material.is_a?(String)
        detected_material = specific_material
      end

      # If no specific material, check instance material
      unless detected_material
        detected_material = instance_material&.display_name || instance_material&.name
      end
      # If still no material, check definition material
      unless detected_material
        detected_material = definition.material&.display_name || definition.material&.name
      end
      
      # Fallback: get dominant material from definition's faces
      unless detected_material
        detected_material = AutoNestCut::Util.get_dominant_material(definition)
      end

      @material = detected_material || 'No Material'
      
      # Get grain direction from attribute dictionaries on the DEFINITION
      # Attribute dictionaries are typically on the definition, not instance for part properties
      @grain_direction = definition.attribute_dictionaries && 
                         (definition.attribute_dictionaries["AutoNestCut"]&.[]("grain_direction") ||
                          definition.attribute_dictionaries["DynamicAttributes"]&.[]("grain_direction")) || 
                         'Any' # Default to 'Any'
      
      # Get edge banding from attribute dictionaries on the DEFINITION
      @edge_banding = definition.attribute_dictionaries && 
                      (definition.attribute_dictionaries["AutoNestCut"]&.[]("edge_banding") ||
                       definition.attribute_dictionaries["DynamicAttributes"]&.[]("edge_banding")) || 
                      'None' # Default to 'None'
      
      # Get texture data from the definition's material if it exists, for rendering purposes
      # Use the material ultimately assigned to the part.
      material_obj = Sketchup.active_model.materials[@material] rescue nil # Try to find material by name
      @texture_data = material_obj ? material_obj.color.to_a : [200, 200, 200]
      # --- END CRITICAL FIXES ---

      @x = 0.0
      @y = 0.0
      @rotated = false
      @instance_id = nil
    end

    def create_placed_instance
      # When creating a placed instance, copy attributes from the original Part
      placed_part = Part.new(@original_definition) # Initialize with original definition
      placed_part.name = @name
      placed_part.width = @width
      placed_part.height = @height
      placed_part.thickness = @thickness
      placed_part.material = @material
      placed_part.grain_direction = @grain_direction
      placed_part.edge_banding = @edge_banding
      placed_part.texture_data = @texture_data # Copy texture data too

      placed_part.instance_id = nil # This is a new placement
      placed_part.x = 0.0
      placed_part.y = 0.0
      placed_part.rotated = false
      placed_part
    end

    def area
      @width * @height
    end

    def rotate!
      # Check if rotation is allowed based on grain_direction
      return false if @grain_direction && ['fixed', 'vertical', 'horizontal'].include?(@grain_direction.downcase)
      @width, @height = @height, @width
      @rotated = !@rotated
      true
    end

    def can_rotate?
      return false if @grain_direction && ['fixed', 'vertical', 'horizontal'].include?(@grain_direction.downcase)
      true
    end

    def fits_in?(board_width, board_height, kerf_width = 0)
      w_with_kerf = @width + kerf_width
      h_with_kerf = @height + kerf_width

      return true if w_with_kerf <= board_width && h_with_kerf <= board_height
      if can_rotate?
        return true if h_with_kerf <= board_width && w_with_kerf <= board_height
      end
      false
    end

    def to_h
      {
        name: @name,
        width: @width.round(2),
        height: @height.round(2),
        thickness: @thickness.round(2),
        material: @material,
        grain_direction: @grain_direction,
        edge_banding: @edge_banding,
        area: area.round(2),
        x: @x.round(2),
        y: @y.round(2),
        rotated: @rotated,
        instance_id: @instance_id,
        texture_data: @texture_data # Include texture_data in hash
      }
    end
  end
end
