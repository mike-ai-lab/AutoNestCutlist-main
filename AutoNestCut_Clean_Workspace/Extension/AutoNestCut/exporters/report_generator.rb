require 'csv'
require_relative '../util' # Ensure Util module is loaded

module AutoNestCut
  class ReportGenerator

    def generate_report_data(boards, settings = {})
      puts "DEBUG: ReportGenerator.generate_report_data called with #{boards.length} boards"
      
      # Get current global settings (always from Config for consistency)
      current_settings = Config.get_cached_settings
      currency = current_settings['default_currency'] || 'USD'
      units = current_settings['units'] || 'mm'
      precision = current_settings['precision'] || 1
      area_units = current_settings['area_units'] || 'm2' # Retrieve area units
      
      puts "DEBUG: Report settings - currency: #{currency}, units: #{units}, precision: #{precision}, area_units: #{area_units}"
      
      # Keep all data in mm for calculation, frontend handles display conversion
      parts_placed_on_boards = []
      unique_part_types_summary = {}

      boards_summary = []
      unique_board_types = {}
      total_waste_area = 0
      overall_total_stock_area = 0

      global_part_instance_counter = 1

      boards.each_with_index do |board, board_idx|
        board_number = board_idx + 1
        board_info = {
          board_number: board_number,
          material: board.material,
          stock_size_mm: "#{board.stock_width.round(1)} x #{board.stock_height.round(1)} mm", # Keep unit for internal representation
          stock_width: board.stock_width,
          stock_height: board.stock_height,
          parts_count: board.parts_on_board.length,
          used_area: board.used_area,
          waste_area: board.waste_area,
          waste_percentage: board.calculate_waste_percentage,
          efficiency_percentage: board.efficiency_percentage, # Corrected key for consistency with frontend
          units: units,
          precision: precision
        }
        boards_summary << board_info

        # Track unique board types
        board_key = "#{board.material}_#{board.stock_width.round(1)}x#{board.stock_height.round(1)}"
        unique_board_types[board_key] ||= {
          material: board.material,
          dimensions_mm: "#{board.stock_width.round(1)} x #{board.stock_height.round(1)} mm",
          stock_width: board.stock_width,
          stock_height: board.stock_height,
          count: 0,
          total_area: 0.0,
          units: units
        }
        unique_board_types[board_key][:count] += 1
        unique_board_types[board_key][:total_area] += board.total_area
        
        # Add pricing calculation with currency (using global default currency for new materials)
        stock_materials = current_settings['stock_materials'] || {} # FIX: Use current_settings
        material_info = stock_materials[board.material]
        if material_info && material_info.is_a?(Hash)
          price = material_info['price'] || 0
          material_currency = material_info['currency'] || currency # Use material's specific currency if saved, else global default
          unique_board_types[board_key][:price_per_sheet] = price
          unique_board_types[board_key][:currency] = material_currency
          unique_board_types[board_key][:total_cost] = unique_board_types[board_key][:count] * price
        else # Fallback for materials not found in stock_materials
          unique_board_types[board_key][:price_per_sheet] = 0
          unique_board_types[board_key][:currency] = currency
          unique_board_types[board_key][:total_cost] = 0
        end

        total_waste_area += board.waste_area
        overall_total_stock_area += board.total_area

        board.parts_on_board.each do |part_instance|
          part_instance.instance_id = "P#{global_part_instance_counter}"
          global_part_instance_counter += 1

          parts_placed_on_boards << {
            part_unique_id: part_instance.instance_id,
            name: part_instance.name,
            width: part_instance.width.round(2),
            height: part_instance.height.round(2),
            thickness: part_instance.thickness.round(2),
            material: part_instance.material,
            area: part_instance.area.round(precision),
            board_number: board_number,
            position_x: part_instance.x.round(2),
            position_y: part_instance.y.round(2),
            rotated: part_instance.rotated ? "Yes" : "No",
            grain_direction: part_instance.grain_direction || "Any",
            edge_banding: part_instance.edge_banding || "None",
            units: units
          }

          unique_part_types_summary[part_instance.name] ||= {
            name: part_instance.name,
            width: part_instance.width.round(2),
            height: part_instance.height.round(2),
            thickness: part_instance.thickness.round(2),
            material: part_instance.material,
            grain_direction: part_instance.grain_direction || "Any",
            edge_banding: part_instance.edge_banding || "None",
            total_quantity: 0,
            total_area: 0.0,
            units: units
          }
          unique_part_types_summary[part_instance.name][:total_quantity] += 1
          unique_part_types_summary[part_instance.name][:total_area] += part_instance.area
        end
      end

      overall_waste_percentage = overall_total_stock_area > 0 ? (total_waste_area.to_f / overall_total_stock_area * 100).round(2) : 0
      
      # Calculate total project cost
      total_project_cost = unique_board_types.values.sum { |board| board[:total_cost] || 0 }

      report_data = {
        parts_placed: parts_placed_on_boards,
        unique_part_types: unique_part_types_summary.values.sort_by { |p| p[:name] },
        unique_board_types: unique_board_types.values.sort_by { |b| b[:material] },
        boards: boards_summary,
        summary: {
          total_parts_instances: parts_placed_on_boards.length,
          total_unique_part_types: unique_part_types_summary.keys.length,
          total_boards: boards.length,
          total_stock_area: overall_total_stock_area.round(precision),
          total_used_area: (overall_total_stock_area - total_waste_area).round(precision),
          total_waste_area: total_waste_area.round(precision),
          overall_waste_percentage: overall_waste_percentage,
          overall_efficiency: (100.0 - overall_waste_percentage),
          total_project_cost: total_project_cost.round(2),
          currency: currency,
          units: units,
          precision: precision,
          area_units: area_units # Pass area units in summary
        }
      }
      
      puts "DEBUG: Generated report data:"
      puts "  - Parts placed: #{parts_placed_on_boards.length}"
      puts "  - Unique part types: #{unique_part_types_summary.keys.length}"
      puts "  - Boards: #{boards.length}"
      puts "  - Total project cost: #{total_project_cost}"
      
      report_data
    end
    
    # Removed deprecated get_unit_factor method, as per debug output it's in Util.rb

    def export_csv(filename, report_data)
      # Use Util.format_dimension and Util.format_area for consistency in CSV
      current_settings = Config.get_cached_settings
      units = current_settings['units'] || 'mm'
      precision = current_settings['precision'] || 1
      area_units = current_settings['area_units'] || 'mm2'

      # FIX: Ensure stock_materials is loaded from settings here
      stock_materials = current_settings['stock_materials'] || {}
      
      # Prepare a map for quick lookup of unique board types and their dimensions/prices
      unique_board_types_map = {}
      (report_data[:unique_board_types] || []).each do |bt|
        unique_board_types_map[bt[:material]] = bt
      end

      CSV.open(filename, 'w') do |csv|
        csv << ["UNIQUE PART TYPES SUMMARY"]
        csv << ["Name", "Width(#{units})", "Height(#{units})", "Thickness(#{units})", "Material", "Grain Direction", "Edge Banding", "Total Quantity", "Total Area(#{area_units})"]
        (report_data[:unique_part_types] || []).each do |part_type|
          csv << [
            part_type[:name].to_s,
            AutoNestCut::Util.convert_units(part_type[:width] || 0, 'mm', units, precision),
            AutoNestCut::Util.convert_units(part_type[:height] || 0, 'mm', units, precision),
            AutoNestCut::Util.convert_units(part_type[:thickness] || 0, 'mm', units, precision),
            part_type[:material].to_s,
            part_type[:grain_direction].to_s,
            part_type[:edge_banding].to_s,
            (part_type[:total_quantity] || 0).to_i,
            AutoNestCut::Util.convert_area_units(part_type[:total_area] || 0, 'mm2', area_units, precision) # Convert area
          ]
        end
        csv << []

        csv << ["PARTS PLACED (DETAILED LIST)"]
        csv << ["Unique ID", "Name", "Width(#{units})", "Height(#{units})", "Thickness(#{units})", "Material", "Area(#{area_units})", "Board#", "X Pos(#{units})", "Y Pos(#{units})", "Rotated", "Grain Direction", "Edge Banding", "Cost"]
        (report_data[:parts_placed] || []).each do |part_instance|
            material_info = stock_materials[part_instance[:material]] # Now `stock_materials` is correctly scoped
            price_per_sheet = material_info ? (material_info['price'] || 0) : 0
            
            board_type_for_part = unique_board_types_map[part_instance[:material]]
            board_width_mm = board_type_for_part ? board_type_for_part[:stock_width] : 2440.0
            board_height_mm = board_type_for_part ? board_type_for_part[:stock_height] : 1220.0
            board_area_mm2 = board_width_mm * board_height_mm

            part_area_mm2 = (part_instance[:width] || 0) * (part_instance[:height] || 0)
            part_cost = board_area_mm2 > 0 ? (part_area_mm2 / board_area_mm2 * price_per_sheet) : 0

            csv << [
            part_instance[:part_unique_id].to_s,
            part_instance[:name].to_s,
            AutoNestCut::Util.convert_units(part_instance[:width] || 0, 'mm', units, precision),
            AutoNestCut::Util.convert_units(part_instance[:height] || 0, 'mm', units, precision),
            AutoNestCut::Util.convert_units(part_instance[:thickness] || 0, 'mm', units, precision),
            part_instance[:material].to_s,
            AutoNestCut::Util.convert_area_units(part_instance[:area] || 0, 'mm2', area_units, precision),
            (part_instance[:board_number] || 0).to_i,
            AutoNestCut::Util.convert_units(part_instance[:position_x] || 0, 'mm', units, precision),
            AutoNestCut::Util.convert_units(part_instance[:position_y] || 0, 'mm', units, precision),
            part_instance[:rotated].to_s,
            part_instance[:grain_direction].to_s,
            part_instance[:edge_banding].to_s,
            # Use the new Util.format_price if MaterialsDatabase.format_price is not available
            AutoNestCut::Util.format_price(part_cost, report_data[:summary][:currency])
          ]
        end
        csv << []

        csv << ["BOARDS SUMMARY"]
        csv << ["Material", "Dimensions (#{units})", "Count", "Total Area (#{area_units})", "Price/Sheet", "Total Cost"]
        (report_data[:unique_board_types] || []).each do |board_type|
          stock_width_display = AutoNestCut::Util.convert_units(board_type[:stock_width] || 0, 'mm', units, precision)
          stock_height_display = AutoNestCut::Util.convert_units(board_type[:stock_height] || 0, 'mm', units, precision)
          dimensions_display = "#{stock_width_display} x #{stock_height_display}"
          
          board_currency_symbol = AutoNestCut::Util.format_price(0, board_type[:currency] || report_data[:summary][:currency]).match(/(\D+)/)&.captures&.first || ''
          
          csv << [
            board_type[:material].to_s,
            dimensions_display,
            (board_type[:count] || 0).to_i,
            AutoNestCut::Util.convert_area_units(board_type[:total_area] || 0, 'mm2', area_units, precision),
            "#{board_currency_symbol}#{'%.2f' % (board_type[:price_per_sheet] || 0).to_f}",
            "#{board_currency_symbol}#{'%.2f' % (board_type[:total_cost] || 0).to_f}"
          ]
        end
        csv << []

        summary = report_data[:summary] || {}
        csv << ["OVERALL SUMMARY"]
        csv << ["Total Parts Instances", (summary[:total_parts_instances] || 0).to_i]
        csv << ["Total Unique Part Types", (summary[:total_unique_part_types] || 0).to_i]
        csv << ["Total Boards", (summary[:total_boards] || 0).to_i]
        csv << ["Total Stock Area (#{area_units})", AutoNestCut::Util.convert_area_units(summary[:total_stock_area] || 0, 'mm2', area_units, precision)]
        csv << ["Total Used Area (#{area_units})", AutoNestCut::Util.convert_area_units(summary[:total_used_area] || 0, 'mm2', area_units, precision)]
        csv << ["Total Waste Area (#{area_units})", AutoNestCut::Util.convert_area_units(summary[:total_waste_area] || 0, 'mm2', area_units, precision)]
        csv << ["Overall Waste %", (summary[:overall_waste_percentage] || 0).to_f.round(precision)]
        csv << ["Overall Efficiency %", (100.0 - (summary[:overall_waste_percentage] || 0)).to_f.round(precision)]
        # Use the new Util.format_price if MaterialsDatabase.format_price is not available
        csv << ["Total Project Cost", AutoNestCut::Util.format_price(summary[:total_project_cost] || 0, summary[:currency])]
      end
    end

    def self.generate_scheduled_report(filters, format)
      # Get current model data
      model = Sketchup.active_model
      selection = model.selection.empty? ? model.entities : model.selection
      
      # Analyze model
      analyzer = AutoNestCut::Processors::ModelAnalyzer.new
      parts_by_material = analyzer.analyze_selection(selection) # Renamed parts to parts_by_material
      
      # Convert the parts_by_material hash into a flat array of part objects for filtering and nesting
      all_parts_for_nesting = []
      parts_by_material.each do |material_name, part_types_array|
        part_types_array.each do |part_type_data|
          part_type = part_type_data[:part_type]
          quantity = part_type_data[:total_quantity]
          quantity.times { all_parts_for_nesting << part_type.create_placed_instance } # Create instances for nesting
        end
      end
      
      # Apply filters
      filtered_parts = apply_filters(all_parts_for_nesting, filters) # Use the flattened array
      
      # Get current global settings (need this for nester)
      current_settings = Config.get_cached_settings
      
      # Generate nesting
      nester = AutoNestCut::Processors::Nester.new
      boards = nester.nest_parts(filtered_parts, current_settings) # Pass settings to nester
      
      # Generate report in requested format
      generator = new
      report_data = generator.generate_report_data(boards, current_settings) # Pass settings to report_data generation
      
      case format.downcase
      when 'csv'
        generate_csv_data(report_data)
      when 'json'
        report_data.to_json
      when 'pdf'
        generate_pdf_data(report_data)
      else
        report_data.to_json
      end
    end
    
    private
    
    def self.apply_filters(parts, filters)
      return parts unless filters && !filters.empty?
      
      filtered = parts
      filtered = filtered.select { |p| p.material == filters['material'] } if filters['material'] && filters['material'] != 'All'
      filtered = filtered.select { |p| p.thickness >= filters['min_thickness'] } if filters['min_thickness'] && filters['min_thickness'].to_f > 0
      filtered = filtered.select { |p| p.thickness <= filters['max_thickness'] } if filters['max_thickness'] && filters['max_thickness'].to_f > 0
      filtered
    end
    
    def self.generate_csv_data(report_data)
      csv_string = ""
      CSV.generate(csv_string) do |csv|
        # Use Util.format_dimension and Util.format_area for consistency in CSV
        current_settings = Config.get_cached_settings
        units = current_settings['units'] || 'mm'
        precision = current_settings['precision'] || 1
        area_units = current_settings['area_units'] || 'mm2'

        csv << ["UNIQUE PART TYPES SUMMARY"]
        csv << ["Name", "Width(#{units})", "Height(#{units})", "Thickness(#{units})", "Material", "Quantity", "Total Area(#{area_units})"]
        (report_data[:unique_part_types] || []).each do |part|
          csv << [
            part[:name],
            AutoNestCut::Util.convert_units(part[:width] || 0, 'mm', units, precision),
            AutoNestCut::Util.convert_units(part[:height] || 0, 'mm', units, precision),
            AutoNestCut::Util.convert_units(part[:thickness] || 0, 'mm', units, precision),
            part[:material],
            part[:total_quantity],
            AutoNestCut::Util.convert_area_units(part[:total_area] || 0, 'mm2', area_units, precision)
          ]
        end
      end
      csv_string
    end
    
    def self.generate_pdf_data(report_data)
      # Simple text-based PDF content
      content = "AutoNestCut Report\n\n"
      content += "Total Parts: #{report_data[:summary][:total_parts_instances]}\n"
      content += "Total Boards: #{report_data[:summary][:total_boards]}\n"
      content += "Efficiency: #{report_data[:summary][:overall_efficiency]}%\n"
      content
    end
  end
end
