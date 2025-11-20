require 'sketchup.rb'
require 'json'

module FacadeMaterialsCalculator
  EXTENSION_NAME = 'Facade Materials Calculator'
  EXTENSION_VERSION = '1.0.0'
  
  def self.show_calculator
    model = Sketchup.active_model
    selection = model.selection

    if selection.empty?
      UI.messagebox("Please select facade surfaces (faces) to analyze for material calculation.")
      return
    end

    html_file = File.join(__dir__, 'facade_ui.html')
    
    dialog = UI::HtmlDialog.new(
      dialog_title: "Facade Materials Calculator",
      preferences_key: "FacadeMaterialsCalculator",
      scrollable: true,
      resizable: true,
      width: 800,
      height: 600
    )
    
    dialog.set_file(html_file)
    
    # Analyze surfaces
    surfaces = analyze_surfaces(selection)
    
    dialog.add_action_callback('get_surface_data') do |context|
      surface_info = {
        count: surfaces.length,
        total_area: surfaces.sum { |s| s[:area_m2] }.round(2),
        surfaces: surfaces,
        detected_dimensions: @detected_dimensions || {}
      }
      dialog.execute_script("displaySurfaceData(#{surface_info.to_json})")
    end
    
    dialog.add_action_callback('get_detected_dimensions') do |context|
      dialog.execute_script("displayDetectedDimensions(#{(@detected_dimensions || {}).to_json})")
    end
    
    dialog.add_action_callback('calculate_materials') do |context, settings_json|
      settings = JSON.parse(settings_json)
      results = calculate_quantities(surfaces, settings)
      dialog.execute_script("displayResults(#{results.to_json})")
    end
    
    dialog.show
  end
  
  def self.analyze_surfaces(selection)
    surfaces = []
    detected_dimensions = { lengths: [], heights: [], thickness: 0 }
    
    selection.each do |entity|
      if entity.is_a?(Sketchup::Group)
        # Analyze stone pieces within the group
        stone_dims = analyze_stone_group(entity)
        detected_dimensions[:lengths].concat(stone_dims[:lengths])
        detected_dimensions[:heights].concat(stone_dims[:heights])
        detected_dimensions[:thickness] = stone_dims[:thickness] if stone_dims[:thickness] > 0
        
        # Calculate total area of the layout
        total_area = calculate_group_area(entity)
        surfaces << {
          area_m2: total_area,
          width: entity.bounds.width.round(2),
          height: entity.bounds.height.round(2),
          orientation: 'vertical',
          stone_dimensions: stone_dims
        }
      elsif entity.is_a?(Sketchup::Face)
        area_m2 = (entity.area * 0.00064516).round(3)
        surfaces << {
          area_m2: area_m2,
          width: entity.bounds.width.round(2),
          height: entity.bounds.height.round(2),
          orientation: get_orientation(entity.normal)
        }
      end
    end
    
    # Store detected dimensions globally
    @detected_dimensions = {
      lengths: detected_dimensions[:lengths].uniq.sort,
      heights: detected_dimensions[:heights].uniq.sort,
      thickness: detected_dimensions[:thickness]
    }
    
    surfaces
  end
  
  def self.get_orientation(normal)
    return 'horizontal' if normal.z.abs > 0.9
    return 'vertical' if normal.z.abs < 0.1
    'sloped'
  end
  
  def self.analyze_stone_group(group)
    lengths = []
    heights = []
    thickness = 0
    
    group.entities.each do |entity|
      next unless entity.is_a?(Sketchup::Face)
      
      # Get face dimensions
      bounds = entity.bounds
      dims = [bounds.width, bounds.height, bounds.depth].sort
      
      # Assume thickness is smallest dimension
      thickness = dims[0] if dims[0] > thickness
      
      # Length and height are the two larger dimensions
      lengths << dims[2].round(1)
      heights << dims[1].round(1)
    end
    
    # Find most common dimensions (filter out edge pieces)
    common_lengths = find_common_dimensions(lengths)
    common_heights = find_common_dimensions(heights)
    
    {
      lengths: common_lengths,
      heights: common_heights,
      thickness: thickness.round(1)
    }
  end
  
  def self.find_common_dimensions(dimensions)
    return [] if dimensions.empty?
    
    # Count frequency of each dimension
    freq = dimensions.group_by(&:itself).transform_values(&:count)
    
    # Return dimensions that appear more than once (common patterns)
    common = freq.select { |dim, count| count > 1 }.keys.sort
    
    # If no common dimensions, return the most frequent ones
    common.empty? ? freq.max_by { |dim, count| count }[0..2].compact : common
  end
  
  def self.calculate_group_area(group)
    total_area = 0
    
    group.entities.each do |entity|
      if entity.is_a?(Sketchup::Face)
        total_area += entity.area
      end
    end
    
    (total_area * 0.00064516).round(3) # Convert to m²
  end
  
  def self.calculate_quantities(surfaces, settings)
    total_area = surfaces.sum { |s| s[:area_m2] }
    
    # Basic calculation based on piece size
    piece_length = settings['piece_length'].to_f
    piece_height = settings['piece_height'].to_f
    joint_width = settings['joint_width'].to_f || 10.0
    waste_factor = settings['waste_factor'].to_f / 100.0 || 0.1
    
    # Calculate pieces per m²
    piece_area_mm2 = (piece_length + joint_width) * (piece_height + joint_width)
    pieces_per_m2 = 1_000_000.0 / piece_area_mm2
    
    total_pieces = (total_area * pieces_per_m2 * (1 + waste_factor)).ceil
    
    {
      total_area: total_area,
      pieces_per_m2: pieces_per_m2.round(2),
      total_pieces: total_pieces,
      waste_pieces: (total_pieces * waste_factor).ceil,
      material_cost: (total_pieces * settings['cost_per_piece'].to_f).round(2)
    }
  end
  
  def self.setup_menu
    menu = UI.menu('Extensions')
    menu.add_item('Facade Materials Calculator') { FacadeMaterialsCalculator.show_calculator }
  end
  
  # Initialize
  setup_menu
  puts "✅ Facade Materials Calculator loaded"
end