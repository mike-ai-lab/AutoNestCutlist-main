require 'json'
require 'thread' # Required for using Ruby's Thread and Queue classes
require 'digest' # Required for generating cache keys (e.g., MD5)
require_relative '../config' # Ensure the Config module is loaded
require_relative '../materials_database' # Ensure MaterialsDatabase is loaded
require_relative '../exporters/report_generator' # Ensure ReportGenerator is loaded
require_relative '../processors/model_analyzer' # Ensure ModelAnalyzer is loaded
require_relative '../processors/nester' # Ensure Nester is loaded
require_relative '../compatibility' # Ensure Compatibility is loaded for desktop_path etc.

module AutoNestCut
  class UIDialogManager

    # Cache for nesting results to avoid recalculating if inputs haven't changed
    # Key: cache_key (MD5 hash of parts and nesting settings), Value: Array of Board objects
    @nesting_cache = {}

    # Flag to indicate if processing was cancelled by user
    @processing_cancelled = false

    def initialize
      # Ensure cache and cancellation flag are initialized for each new manager instance
      @nesting_cache = {}
      @processing_cancelled = false
    end

    def show_config_dialog(parts_by_material, original_components = [], hierarchy_tree = [])
      @parts_by_material = parts_by_material
      @original_components = original_components
      @hierarchy_tree = hierarchy_tree
      
      # Use HtmlDialog for SU2017+ or WebDialog for older versions
      if defined?(UI::HtmlDialog)
        @dialog = UI::HtmlDialog.new(
          dialog_title: "AutoNestCut",
          preferences_key: "AutoNestCut_Main",
          scrollable: true,
          resizable: true,
          width: 360, # Keeping user's specified compact width
          height: 590 # Keeping user's specified compact height
        )
      else
        @dialog = UI::WebDialog.new(
          "AutoNestCut",
          true,
          "AutoNestCut_Main",
          1200, # Fallback to a larger size for WebDialog
          750,
          100,
          100,
          true
        )
      end

      html_file = File.join(__dir__, 'html', 'main.html')
      @dialog.set_file(html_file)

      # Send initial data to dialog when it's ready
      @dialog.add_action_callback("ready") do |action_context|
        puts "DEBUG: Frontend is ready. Sending initial data."
        send_initial_data
      end

      # Handle global settings update from UI (units, precision, currency, area_units)
      @dialog.add_action_callback("update_global_setting") do |action_context, setting_json|
        begin
          setting_data = JSON.parse(setting_json)
          key = setting_data['key']
          value = setting_data['value']
          
          # Use Config module for persistence
          Config.save_global_settings({key => value})
          puts "DEBUG: Global setting updated: #{key} = #{value}"
          
          # After updating a global setting, re-send initial data to ensure UI consistency
          # The JS `receiveInitialData` will then trigger `displayMaterials` and `renderReport` as needed.
          send_initial_data
        rescue => e
          puts "ERROR updating global setting: #{e.message}"
          @dialog.execute_script("showError('Error updating setting: #{e.message.gsub("'", "\\'")}')")
        end
      end

      # Handle materials database save from UI
      @dialog.add_action_callback("save_materials") do |action_context, materials_json|
        begin
          materials = JSON.parse(materials_json)
          MaterialsDatabase.save_database(materials)
          puts "DEBUG: Materials database saved successfully."
        rescue => e
          puts "ERROR saving materials: #{e.message}"
          @dialog.execute_script("showError('Error saving materials: #{e.message.gsub("'", "\\'")}')")
        end
      end

      # Handle processing (nesting and report generation)
      @dialog.add_action_callback("process") do |action_context, settings_json|
        begin
          new_settings_from_ui = JSON.parse(settings_json)
          
          # Save global settings from the UI's full settings object
          Config.save_global_settings({
            'kerf_width' => new_settings_from_ui['kerf_width'],
            'allow_rotation' => new_settings_from_ui['allow_rotation'],
            'default_currency' => new_settings_from_ui['default_currency'],
            'units' => new_settings_from_ui['units'],
            'precision' => new_settings_from_ui['precision'],
            'area_units' => new_settings_from_ui['area_units']
          })
          
          # Save material data (including updates to prices/dimensions if any)
          MaterialsDatabase.save_database(new_settings_from_ui['stock_materials'])

          # Always use async processing for nesting (with caching)
          # Fetch the *latest* settings from Config for processing to ensure consistency
          latest_settings = Config.get_cached_settings
          
          # Combine detected materials with stock materials for Nester input
          # This ensures that Nester has correct dimensions for ALL materials,
          # including those dynamically added from the model if not in stock_materials.
          all_materials_for_nester = MaterialsDatabase.load_database # Start with stock
          
          # Merge in properties from `parts_by_material` for detected but not defined materials
          @parts_by_material.each do |material_name, part_types|
            if !all_materials_for_nester.key?(material_name)
                # If a detected material is not in stock_materials, create a default entry for it.
                # Nester needs dimensions for all materials it encounters.
                first_part_type_data = part_types.first # This is a hash like {:part_type=>PartObject, :total_quantity=>1}
                
                # Initialize thickness_val with a default
                thickness_val = 18.0
                
                part_obj_from_entry = nil
                if first_part_type_data.is_a?(Hash) && first_part_type_data.key?(:part_type)
                  part_obj_from_entry = first_part_type_data[:part_type]
                elsif first_part_type_data.is_a?(AutoNestCut::Part)
                  part_obj_from_entry = first_part_type_data
                end

                if part_obj_from_entry.is_a?(AutoNestCut::Part) && part_obj_from_entry.respond_to?(:thickness)
                  thickness_val = part_obj_from_entry.thickness
                end
                
                all_materials_for_nester[material_name] = {
                    'width' => 2440, # Default board size
                    'height' => 1220,
                    'thickness' => thickness_val, # Use the determined thickness_val
                    'price' => 0,
                    'currency' => latest_settings['default_currency'] || 'USD'
                }
            end
          end
          latest_settings['stock_materials'] = all_materials_for_nester # Update settings for Nester

          process_with_async_nesting(latest_settings)

        rescue => e
          puts "ERROR in process callback: #{e.message}"
          puts e.backtrace
          @dialog.execute_script("showError('Error processing: #{e.message.gsub("'", "\\'")}')")
          @dialog.execute_script("hideProgressOverlay()")
        end
      end

      # Export CSV report
      @dialog.add_action_callback("export_csv") do |action_context, report_data_json|
        begin
          if report_data_json && !report_data_json.empty?
            report_data = JSON.parse(report_data_json, symbolize_names: true)
            # Pass the latest global settings for unit/precision/currency handling in CSV export
            export_csv_report(report_data, Config.get_cached_settings)
          else
            UI.messagebox("Error exporting CSV: No report data available")
          end
        rescue => e
          UI.messagebox("Error exporting CSV: #{e.message}")
        end
      end

      @dialog.add_action_callback("export_html") do |action_context|
        # HTML export is handled entirely in JavaScript
        # This callback exists for potential future server-side HTML generation
      end

      @dialog.add_action_callback("back_to_config") do |action_context|
        @dialog.execute_script("showConfigTab()")
      end

      @dialog.add_action_callback("load_default_materials") do |action_context|
        puts "DEBUG: Loading default materials."
        defaults = MaterialsDatabase.get_default_materials
        MaterialsDatabase.save_database(defaults)
        send_initial_data # Refresh UI with new defaults
      end

      @dialog.add_action_callback("import_materials_csv") do |action_context|
        puts "DEBUG: Importing materials CSV."
        file_path = UI.openpanel("Select Materials CSV File", "", "CSV Files|*.csv||")
        if file_path
          imported = MaterialsDatabase.import_csv(file_path)
          unless imported.empty?
            existing = MaterialsDatabase.load_database
            merged = existing.merge(imported)
            MaterialsDatabase.save_database(merged)
            send_initial_data # Refresh UI
            UI.messagebox("Imported #{imported.keys.length} materials successfully!")
          else
            UI.messagebox("No valid materials found in CSV file.")
          end
        end
      end

      @dialog.add_action_callback("export_materials_database") do |action_context|
        puts "DEBUG: Exporting materials database."
        desktop_path = Compatibility.desktop_path
        filename = "AutoNestCut_Materials_Database_#{Time.now.strftime('%Y%m%d')}.csv"
        file_path = File.join(desktop_path, filename)

        materials = MaterialsDatabase.load_database
        # Save before copying to ensure latest data is written
        MaterialsDatabase.save_database(materials)

        # Copy to desktop
        require 'fileutils'
        FileUtils.cp(MaterialsDatabase.database_file, file_path)
        UI.messagebox("Materials database exported to Desktop: #{filename}")
      end

      @dialog.add_action_callback("highlight_material") do |action_context, material_name|
        highlight_components_by_material(material_name)
      end

      @dialog.add_action_callback("clear_highlight") do |action_context|
        clear_component_highlight
      end

      @dialog.add_action_callback("refresh_config") do |action_context|
        puts "DEBUG: Frontend requested config refresh."
        # Invalidate cache when input components are refreshed, as parts_by_material will change
        @nesting_cache = {}
        @last_processed_cache_key = nil # Clear the last key too
        refresh_configuration_data
      end

      @dialog.add_action_callback("refresh_report") do |action_context|
        puts "DEBUG: Frontend requested report refresh."
        # This means recalculate report data with current settings, not re-nest the parts
        # Pass current settings to ensure the report reflects them (e.g., unit/currency changes)
        refresh_report_display_with_current_settings
      end
      
      @dialog.add_action_callback("cancel_processing") do |action_context|
        @processing_cancelled = true
        @dialog.execute_script("updateProgressOverlay('Cancelling process...', 0)")
      end
      
      @dialog.add_action_callback("clear_nesting_cache") do |action_context|
        @nesting_cache = {}
        @last_processed_cache_key = nil
        puts "Nesting cache cleared manually"
      end

      @dialog.show
    end

    private

    # Sends all initial data (settings, parts, materials, etc.) to the frontend
    def send_initial_data
      # Load all materials from the database first
      loaded_materials = MaterialsDatabase.load_database
      
      # Get current global settings from a configuration manager (e.g., Config.rb)
      current_settings = Config.get_cached_settings

      # Ensure `stock_materials` in settings reflects the loaded database
      current_settings['stock_materials'] = loaded_materials

      # Auto-load detected materials into stock_materials for UI display if they don't exist
      @parts_by_material.each do |material_name, part_types|
        unless current_settings['stock_materials'].key?(material_name)
          thickness_val = 18.0 # Default fallback thickness

          first_part_entry = part_types.first
          
          # Explicitly extract the Part object if it's a hash with :part_type
          part_obj_from_entry = nil
          if first_part_entry.is_a?(Hash) && first_part_entry.key?(:part_type)
            part_obj_from_entry = first_part_entry[:part_type]
          elsif first_part_entry.is_a?(AutoNestCut::Part) # Fallback if part_types contains Part objects directly
            part_obj_from_entry = first_part_entry
          end

          if part_obj_from_entry.is_a?(AutoNestCut::Part) && part_obj_from_entry.respond_to?(:thickness)
            thickness_val = part_obj_from_entry.thickness
          end
          
          current_settings['stock_materials'][material_name] = {
            'width' => 2440, # Default board size
            'height' => 1220,
            'thickness' => thickness_val, # Use the determined thickness_val
            'price' => 0,
            'currency' => current_settings['default_currency'] || 'USD'
          }
        end
      end
      # Save these potentially new materials to the database so they persist
      MaterialsDatabase.save_database(current_settings['stock_materials'])

      # Combine initial data for frontend
      initial_data = {
        settings: current_settings, # Contains global settings (units, currency, etc.) and stock_materials
        parts_by_material: serialize_parts_by_material(@parts_by_material),
        original_components: @original_components,
        model_materials: get_model_materials, # Materials from SketchUp model
        hierarchy_tree: @hierarchy_tree
      }
      
      script = "receiveInitialData(#{initial_data.to_json})"
      @dialog.execute_script(script)
    rescue => e
      puts "ERROR in send_initial_data: #{e.message}"
      puts e.backtrace
      @dialog.execute_script("showError('Error loading initial data: #{e.message.gsub("'", "\\'")}')")
    end

    # ======================================================================================
    # ASYNCHRONOUS NESTING PROCESSING WITH CACHING
    # ======================================================================================

    # Queue for communication between background thread and UI thread
    @nesting_queue = nil
    # Reference to the background thread
    @nesting_thread = nil
    # Reference to the UI timer for watching the queue
    @nesting_watcher_timer = nil

    # Store the cache key of the last successfully processed nesting
    @last_processed_cache_key = nil

    # Generates a unique, stable hash key for the given parts and settings
    def generate_cache_key(parts_by_material_hash, settings)
      # Return a distinct key for empty parts to avoid accidental cache hits
      return Digest::MD5.hexdigest("EMPTY_PARTS_#{Time.now.to_i}") if parts_by_material_hash.nil? || parts_by_material_hash.empty?

      # Create a canonical representation of parts_by_material
      serialized_parts = parts_by_material_hash.map do |material, parts_array|
        [material.to_s, parts_array.map do |part_entry|
          part_type = part_entry.is_a?(Hash) && part_entry.key?(:part_type) ? part_entry[:part_type] : part_entry
          {
            name: part_type.name.to_s,
            width: part_type.width.to_f,
            height: part_type.height.to_f,
            thickness: part_type.thickness.to_f, # Include thickness in cache key
            total_quantity: (part_entry[:total_quantity] || 1).to_i
          }
        end.sort_by { |p| [p[:name], p[:width], p[:height], p[:thickness], p[:total_quantity]] }]
      end.sort_by(&:first).to_json

      # Extract only nesting-relevant settings that affect the *nesting pattern* or *outcome*
      nesting_stock_materials = if settings['stock_materials']
                                  settings['stock_materials'].transform_values do |material_data|
                                    material_data.reject { |k, _v| k == 'price' || k == 'currency' } # Remove price and currency from cache key
                                  end
                                else
                                  {}
                                end

      nesting_settings = {
        'stock_materials' => nesting_stock_materials,
        'kerf_width' => settings['kerf_width'],
        'allow_rotation' => settings['allow_rotation']
        # Add any other settings from Config that directly influence the nesting result
      }.to_json

      # Combine and hash
      Digest::MD5.hexdigest(serialized_parts + nesting_settings)
    end

    def process_with_async_nesting(settings)
      @processing_cancelled = false # Reset cancellation flag at the start of a new process

      @dialog.execute_script("showProgressOverlay('Preparing optimization...', 0)")

      @settings = settings # Store current settings for report generation later
      @boards = [] # Clear previous boards data

      # Initialize communication queue and thread references
      @nesting_queue = Queue.new
      @nesting_thread = nil
      @nesting_watcher_timer = nil

      current_cache_key = generate_cache_key(@parts_by_material, settings)

      if @nesting_cache.key?(current_cache_key)
        # --- CACHE HIT ---
        @dialog.execute_script("updateProgressOverlay('Using cached results...', 10)")
        cached_boards = @nesting_cache[current_cache_key]
        @last_processed_cache_key = current_cache_key

        # Simulate quick completion with a very short timer to allow UI update
        UI.start_timer(0.01, false) do
          generate_report_and_show_tab(cached_boards)
          @dialog.execute_script("hideProgressOverlay()")
        end
      else
        # --- CACHE MISS ---
        start_nesting_background_thread(current_cache_key) # Pass key to store results later
        start_nesting_progress_watcher
      end
    end

    # Starts the heavy nesting computation in a separate background thread
    def start_nesting_background_thread(cache_key)
      parts_by_material_for_thread = @parts_by_material.dup
      settings_for_thread = @settings.dup

      @nesting_thread = Thread.new do
        begin
          nester = Nester.new
          boards_result = []
          
          nester_progress_callback = lambda do |message, percentage|
            unless @processing_cancelled
              @nesting_queue.push({ type: :progress, message: message, percentage: percentage })
            end
          end

          @nesting_queue.push({ type: :progress, message: "Starting optimization...", percentage: 5 })
          boards_result = nester.optimize_boards(parts_by_material_for_thread, settings_for_thread, nester_progress_callback)
          
          if @processing_cancelled
            @nesting_queue.push({ type: :cancelled })
          else
            @nesting_queue.push({ type: :complete, boards: boards_result, cache_key: cache_key })
          end

        rescue StandardError => e
          puts "Background nesting thread error: #{e.message}\n#{e.backtrace.join("\n")}"
          @nesting_queue.push({ type: :error, message: "Nesting calculation failed: #{e.message}" })
        end
      end
    end

    # Starts a UI timer to periodically check the queue for messages from the background thread
    def start_nesting_progress_watcher
      @nesting_watcher_timer = UI.start_timer(0.1, true) do
        process_queue_message # Process one message at a time to prevent blocking
      end
    end

    # Processes a single message from the queue on the main UI thread
    def process_queue_message
      return unless @nesting_queue
      return if @nesting_queue.empty?

      message = @nesting_queue.pop(true)

      case message[:type]
      when :progress
        pct = message[:percentage].clamp(0, 100)
        @dialog.execute_script("updateProgressOverlay('#{message[:message].gsub("'", "\\'")}', #{pct})")
      when :error
        finalize_nesting_process
        @dialog.execute_script("hideProgressOverlay()")
        @dialog.execute_script("showError('#{message[:message].gsub("'", "\\'")}')")
      when :cancelled
        finalize_nesting_process
        @dialog.execute_script("hideProgressOverlay()")
        @dialog.execute_script("showError('Nesting process cancelled by user.')") # Changed to showError for explicit feedback
      when :complete
        @dialog.execute_script("updateProgressOverlay('All nesting calculations complete. Preparing reports...', 90)")
        
        finalize_nesting_process 

        @boards = message[:boards]
        @last_processed_cache_key = message[:cache_key]

        if message[:cache_key] && @boards
          @nesting_cache[message[:cache_key]] = @boards
          puts "Nesting results cached for key: #{message[:cache_key]}"
        end
        
        UI.start_timer(0.01, false) do
          generate_report_and_show_tab(@boards)
        end
      end
    rescue ThreadError
      # Ignore, just means no message was available this tick.
    end

    # Cleans up the background thread and UI timer
    def finalize_nesting_process
      if @nesting_watcher_timer && (defined?(UI.valid_timer?) ? UI.valid_timer?(@nesting_watcher_timer) : true)
        UI.stop_timer(@nesting_watcher_timer)
      end
      @nesting_watcher_timer = nil

      if @nesting_thread && @nesting_thread.alive?
        @nesting_thread.kill
        @nesting_thread.join
      end
      @nesting_thread = nil

      @nesting_queue.clear if @nesting_queue
      @nesting_queue = nil

      @processing_cancelled = false
    end

    # Generates the report data and displays the report tab in the dialog
    def generate_report_and_show_tab(boards)
      @dialog.execute_script("updateProgressOverlay('Generating reports...', 95)")

      if boards.empty?
        @dialog.execute_script("hideProgressOverlay()")
        @dialog.execute_script("showError('No boards could be generated. Please check your material settings and part dimensions.')")
        return
      end

      # Perform actual report data generation (passing the current @settings)
      report_generator = ReportGenerator.new
      report_data = report_generator.generate_report_data(boards, @settings)

      # Prepare data for dialog
      data = {
        diagrams: boards.map(&:to_h), # Assuming Board objects have a to_h method
        report: report_data,
        original_components: @original_components,
        hierarchy_tree: @hierarchy_tree
      }

      @dialog.execute_script("updateProgressOverlay('Finalizing...', 100)")
      @dialog.execute_script("hideProgressOverlay()")
      @dialog.execute_script("showReportTab(#{data.to_json})")
    rescue StandardError => e
      puts "ERROR in generate_report_and_show_tab: #{e.message}"
      puts e.backtrace
      @dialog.execute_script("hideProgressOverlay()")
      @dialog.execute_script("showError('Error generating report: #{e.message.gsub("'", "\\'")}')")
    end

    # ======================================================================================
    # END ASYNCHRONOUS NESTING PROCESSING
    # ======================================================================================

    def serialize_parts_by_material(parts_by_material_hash)
      result = {}
      parts_by_material_hash.each do |material, parts|
        result[material] = parts.map do |part_entry|
          # Robustly extract Part object
          part_type_obj = nil
          if part_entry.is_a?(Hash) && part_entry.key?(:part_type)
            part_type_obj = part_entry[:part_type]
          elsif part_entry.is_a?(AutoNestCut::Part)
            part_type_obj = part_entry
          end

          if part_type_obj.is_a?(AutoNestCut::Part)
            {
              name: part_type_obj.name,
              width: part_type_obj.width,
              height: part_type_obj.height,
              thickness: part_type_obj.thickness, # Include thickness
              total_quantity: part_entry[:total_quantity] || 1
            }
          else
            # Fallback for unexpected part_entry format, or raise error for debug
            puts "Warning: Unexpected part_entry format in serialize_parts_by_material: #{part_entry.inspect}"
            {
              name: 'UNKNOWN_PART',
              width: 0,
              height: 0,
              thickness: 0,
              total_quantity: part_entry[:total_quantity] || 1
            }
          end
        end
      end
      result
    end

    def get_model_materials
      materials = []
      Sketchup.active_model.materials.each do |material|
        materials << {
          name: material.display_name || material.name,
          color: material.color ? material.color.to_a[0..2] : [200, 200, 200]
        }
      end
      materials
    end

    def highlight_components_by_material(material_name)
      model = Sketchup.active_model
      selection = model.selection
      selection.clear

      matching_entities = []

      if @original_components && !@original_components.empty?
        @original_components.each do |comp_data|
          # Use string comparison for material names
          if comp_data[:material].to_s.strip.downcase == material_name.to_s.strip.downcase
            found_entity = find_entity_by_id(model, comp_data[:entity_id])
            if found_entity
              matching_entities << found_entity
            end
          end
        end
      end
      
      model.selection.add(matching_entities)

      if matching_entities.any?
        view = model.active_view
        view.zoom(matching_entities)
      else
        puts "DEBUG: No components found with material: #{material_name}"
        UI.messagebox("No components found with material: #{material_name}")
      end
    end

    # Helper method to find an entity by its ID recursively in the model
    def find_entity_by_id(model, entity_id)
      return nil unless entity_id

      # First, check model.find_entities_by_id (if available and entity_id is a valid ID from SketchUp::Entity)
      # Note: model.find_entities_by_id expects an array of IDs and returns entities.
      # For a single ID, iterating is generally safer or using specific methods.
      # If entity_id is not an integer (e.g., from an attribute), this won't work.
      # Assuming entity_id is from Sketchup::Entity#entityID, which is an integer.
      
      # Simpler direct iteration approach:
      model.entities.each do |entity|
        return entity if entity.entityID == entity_id
        if entity.is_a?(Sketchup::Group)
          found = find_entity_in_container(entity, entity_id)
          return found if found
        elsif entity.is_a?(Sketchup::ComponentInstance)
          # Search inside the component's definition entities
          found = find_entity_in_container(entity.definition, entity_id)
          return found if found
        end
      end
      nil
    end

    # Recursive helper for find_entity_by_id
    def find_entity_in_container(container, entity_id)
      return nil unless container.respond_to?(:entities)

      container.entities.each do |entity|
        return entity if entity.entityID == entity_id
        if entity.is_a?(Sketchup::Group)
          found = find_entity_in_container(entity, entity_id)
          return found if found
        elsif entity.is_a?(Sketchup::ComponentInstance)
          found = find_entity_in_container(entity.definition, entity_id)
          return found if found
        end
      end
      nil
    end

    def clear_component_highlight
      Sketchup.active_model.selection.clear
    end

    def refresh_configuration_data
      model = Sketchup.active_model
      selection = model.selection

      if selection.empty?
        @dialog.execute_script("showError('Please select components or groups to analyze for refresh.')")
        return
      end

      begin
        analyzer = ModelAnalyzer.new
        @parts_by_material = analyzer.analyze_selection(selection) # Use the more comprehensive analyze_selection
        @original_components = analyzer.get_original_components_data
        @hierarchy_tree = analyzer.get_hierarchy_tree

        if @parts_by_material.empty?
          @dialog.execute_script("showError('No valid sheet good parts found in your selection.')")
          return
        end

        # Send refreshed data to the dialog. `send_initial_data` already handles populating settings
        # and stock materials from detected parts.
        send_initial_data
      rescue => e
        puts "ERROR refreshing data: #{e.message}"
        puts e.backtrace
        @dialog.execute_script("showError('Error refreshing data: #{e.message.gsub("'", "\\'")}')")
      end
    end

    # Refreshes only the report display using the last computed boards and current settings
    def refresh_report_display_with_current_settings
      return unless @boards && !@boards.empty? # Ensure boards are available from a previous run

      # Load current settings, as display-only settings might have changed since last nesting
      @settings = Config.get_cached_settings # Update @settings to ensure report generation uses latest config

      begin
        generate_report_and_show_tab(@boards)
      rescue => e
        puts "ERROR refreshing report display: #{e.message}"
        puts e.backtrace
        @dialog.execute_script("showError('Error refreshing report display: #{e.message.gsub("'", "\\'")}')")
      end
    end

    def export_csv_report(report_data, global_settings)
      model_name = Sketchup.active_model.title.empty? ? "Untitled" : Sketchup.active_model.title.gsub(/[^\w]/, '_')

      base_name = "Cutting_List_#{model_name}"
      counter = 1

      desktop_path = Compatibility.desktop_path

      loop do
        filename = "#{base_name}_#{counter}.csv"
        full_path = File.join(desktop_path, filename)

        unless File.exist?(full_path)
          begin
            reporter = ReportGenerator.new
            # Pass global settings to export_csv for unit, precision, currency consistency
            reporter.export_csv(full_path, report_data, global_settings) # Pass global_settings here
            UI.messagebox("Cut list exported to Desktop: #{filename}")
            return
          rescue => e
            puts "ERROR exporting CSV: #{e.message}"
            puts e.backtrace
            UI.messagebox("Error exporting CSV: #{e.message}")
            return
          end
        end

        counter += 1
      end
    end
  end
end
