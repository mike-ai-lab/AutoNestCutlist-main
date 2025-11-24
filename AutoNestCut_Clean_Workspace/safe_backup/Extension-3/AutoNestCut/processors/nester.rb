module AutoNestCut
  class Nester

    def optimize_boards(part_types_by_material_and_quantities, settings, progress_callback = nil)
      boards = []
      stock_materials_config = settings['stock_materials']
      kerf_width = settings['kerf_width'].to_f || 3.0
      allow_rotation = settings['allow_rotation'] || true
      @progress_callback = progress_callback # Storing for internal use
      
      total_materials = part_types_by_material_and_quantities.keys.length
      
      part_types_by_material_and_quantities.each_with_index do |(material, types_and_quantities_for_material), material_index|
        # Base progress for this material (out of the 80% range allocated for nesting)
        current_material_base_progress = (material_index.to_f / total_materials * 80).round(1) 
        
        if @progress_callback
          @progress_callback.call("Processing material: #{material}...", current_material_base_progress)
        end
        
        stock_dims = stock_materials_config[material]
        if stock_dims.nil?
          stock_width, stock_height = 2440.0, 1220.0
          Util.debug("Using default sheet size for material: #{material}")
        elsif stock_dims.is_a?(Hash)
          stock_width = stock_dims['width'].to_f
          stock_height = stock_dims['height'].to_f
        elsif stock_dims.is_a?(Array) && stock_dims.length == 2
          stock_width, stock_height = stock_dims[0].to_f, stock_dims[1].to_f
        else
          stock_width, stock_height = 2440.0, 1220.0
        end

        all_individual_parts_to_place = []
        total_parts_for_material = types_and_quantities_for_material.sum { |entry| entry[:total_quantity] }
        created_parts_count = 0
        
        types_and_quantities_for_material.each do |entry|
          part_type = entry[:part_type]
          total_quantity = entry[:total_quantity]
          total_quantity.times do
            created_parts_count += 1
            
            # Sub-progress for part creation within current material (allocate 10% of material's progress)
            if @progress_callback && (created_parts_count % 50 == 0 || created_parts_count == total_parts_for_material)
              sub_progress_in_material_creation = (created_parts_count.to_f / total_parts_for_material * 10).round(1)
              overall_progress = current_material_base_progress + sub_progress_in_material_creation
              @progress_callback.call("Preparing parts for #{material}: #{created_parts_count}/#{total_parts_for_material}", overall_progress)
            end
            
            individual_part_instance = part_type.create_placed_instance
            all_individual_parts_to_place << individual_part_instance
            
            # Removed sleep calls - they are detrimental to performance in a background thread
          end
        end

        # Progress update before actual nesting for the material begins
        if @progress_callback
          @progress_callback.call("Nesting parts for #{material}...", current_material_base_progress + 10) # 10% for part creation
        end

        material_boards = nest_individual_parts(all_individual_parts_to_place, material, stock_width, stock_height, kerf_width, allow_rotation, @progress_callback, current_material_base_progress + 10, total_materials)
        boards.concat(material_boards)
        
        # Removed sleep calls between materials
      end
      
      if @progress_callback
        @progress_callback.call("Nesting optimization complete!", 90) # Signal 90% before returning
      end
      
      boards
    end

    private

    def nest_individual_parts(individual_parts_to_place, material, stock_width, stock_height, kerf_width, allow_rotation, progress_callback = nil, base_overall_progress = 0, total_materials = 1)
      boards = []
      remaining_parts = individual_parts_to_place.dup

      # Sort by area descending is a common heuristic for better packing
      remaining_parts.sort_by! { |part_instance| -part_instance.area }

      board_count = 0
      total_parts_initial = individual_parts_to_place.length # for more precise progress
      placed_parts_global = 0

      # Allocate 70% of the material's total 80% range for actual nesting
      nesting_progress_range_for_material = (80.0 / total_materials * 0.70).round(1)

      while !remaining_parts.empty?
        board_count += 1
        board = Board.new(material, stock_width, stock_height)
        parts_successfully_placed_on_this_board = []
        parts_that_could_not_fit_yet = []

        # Iterate through remaining parts, trying to place them on the current board
        remaining_parts.each_with_index do |part_instance, idx|
          if try_place_part_on_board(part_instance, board, kerf_width, allow_rotation)
            parts_successfully_placed_on_this_board << part_instance
            placed_parts_global += 1
          else
            parts_that_could_not_fit_yet << part_instance
          end

          # Update progress for nesting within a board
          if progress_callback && (idx % 20 == 0 || idx == remaining_parts.length - 1)
            # Calculate progress within the nesting phase for this material
            current_nesting_progress = (placed_parts_global.to_f / total_parts_initial * nesting_progress_range_for_material).round(1)
            overall_progress = base_overall_progress + current_nesting_progress
            progress_callback.call("Placing parts on board ##{board_count} for #{material}. Placed: #{placed_parts_global}/#{total_parts_initial}...", overall_progress)
          end
        end
        
        remaining_parts = parts_that_could_not_fit_yet

        if !parts_successfully_placed_on_this_board.empty?
          boards << board
        else
          # If no parts could be placed on a new board, it means the remaining parts
          # are either too large for any stock or cannot fit due to kerf/gaps.
          # We break to avoid infinite loops with unplaceable parts.
          break
        end
      end
      boards
    end

    def try_place_part_on_board(part_instance, board, kerf_width, allow_rotation)
      # Store original dimensions to revert if rotation doesn't work
      original_width = part_instance.width
      original_height = part_instance.height
      original_rotated_state = part_instance.rotated

      # Try current orientation
      position = board.find_best_position(part_instance, kerf_width)
      if position
        board.add_part(part_instance, position[0], position[1], kerf_width) # Pass kerf_width to add_part
        return true
      end

      # Try rotated orientation if allowed and not already rotated
      if allow_rotation && part_instance.can_rotate? && !part_instance.rotated
        part_instance.rotate! # This should swap width/height and set rotated=true
        position = board.find_best_position(part_instance, kerf_width)
        if position
          board.add_part(part_instance, position[0], position[1], kerf_width) # Pass kerf_width to add_part
          return true
        else
          # If rotated part doesn't fit, revert to original state
          part_instance.rotate! # Rotate back to original
          part_instance.width = original_width # Ensure dimensions are exactly reverted
          part_instance.height = original_height
          part_instance.rotated = original_rotated_state
        end
      end
      false
    end
  end
end
