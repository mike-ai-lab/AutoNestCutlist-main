require 'json'
require 'thread' # Required for using Ruby's Thread and Queue classes
require 'digest' # Required for generating cache keys (e.g., MD5)

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
      settings = Config.load_settings

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

      # Send initial data to dialog
      @dialog.add_action_callback("ready") do |action_context|
        # Auto-load detected materials into settings
        settings['stock_materials'] ||= {}
        parts_by_material.keys.each do |material|
          unless settings['stock_materials'][material]
            settings['stock_materials'][material] = { 'width' => 2440, 'height' => 1220, 'price' => 0 }
          end
        end

        data = {
          settings: settings,
          parts_by_material: serialize_parts_by_material(parts_by_material),
          original_components: original_components,
          model_materials: get_model_materials,
          hierarchy_tree: @hierarchy_tree
        }
        @dialog.execute_script("receiveInitialData(#{data.to_json})")
      end

      # Handle settings save and process
      @dialog.add_action_callback("process") do |action_context, settings_json|
        begin
          new_settings = JSON.parse(settings_json)
          Config.save_settings(new_settings)

          # Always use async processing for nesting (with caching)
          process_with_async_nesting(new_settings)

        rescue => e
          @dialog.execute_script("showError('Error processing: #{e.message.gsub("'", "\\'")}')")
        end
      end

      @dialog.add_action_callback("export_csv") do |action_context, report_data_json|
        begin
          if report_data_json && !report_data_json.empty?
            report_data = JSON.parse(report_data_json, symbolize_names: true)
            export_csv_report(report_data)
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
        defaults = MaterialsDatabase.get_default_materials
        MaterialsDatabase.save_database(defaults)
        @dialog.execute_script("location.reload()")
      end

      @dialog.add_action_callback("import_materials_csv") do |action_context|
        file_path = UI.openpanel("Select Materials CSV File", "", "CSV Files|*.csv||")
        if file_path
          imported = MaterialsDatabase.import_csv(file_path)
          unless imported.empty?
            existing = MaterialsDatabase.load_database
            merged = existing.merge(imported)
            MaterialsDatabase.save_database(merged)
            @dialog.execute_script("location.reload()")
            UI.messagebox("Imported #{imported.keys.length} materials successfully!")
          else
            UI.messagebox("No valid materials found in CSV file.")
          end
        end
      end

      @dialog.add_action_callback("export_materials_database") do |action_context|
        desktop_path = Compatibility.desktop_path
        filename = "AutoNestCut_Materials_Database_#{Time.now.strftime('%Y%m%d')}.csv"
        file_path = File.join(desktop_path, filename)

        materials = MaterialsDatabase.load_database
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
        # Invalidate cache when input components are refreshed, as parts_by_material will change
        @nesting_cache = {}
        @last_processed_cache_key = nil # Clear the last key too
        refresh_configuration_data
      end

      @dialog.add_action_callback("refresh_report") do |action_context|
        # This means recalculate report data with current settings, not re-nest the parts
        refresh_report_display_with_current_settings
      end

      @dialog.add_action_callback("update_global_setting") do |action_context, setting_json|
        begin
          setting_data = JSON.parse(setting_json)
          key = setting_data['key']
          value = setting_data['value']
          Config.update_global_setting(key, value)

          # If a global setting affects NESTING (e.g., gap_size), the cache should be cleared.
          # For simplicity, if any setting in `nesting_params` or stock materials (that are part of key)
          # is updated, the cache might need invalidation. For now, assuming direct "process" click handles this.
        rescue => e
          puts "Error updating global setting: #{e.message}"
        end
      end

      @dialog.add_action_callback("save_settings") do |action_context, settings_json|
        begin
          settings = JSON.parse(settings_json)
          Config.save_settings(settings)

          # Invalidate cache if settings that affect nesting have changed.
          # We generate a new cache key and compare it to the last one used for a successful process.
          current_computed_cache_key = generate_cache_key(@parts_by_material, settings)
          if @last_processed_cache_key && current_computed_cache_key != @last_processed_cache_key
            @nesting_cache = {}
            @last_processed_cache_key = nil
            puts "Nesting cache cleared due to relevant settings change."
          end
        rescue => e
          puts "Error saving settings: #{e.message}"
        end
      end
      
      @dialog.add_action_callback("cancel_processing") do |action_context|
        @processing_cancelled = true
        # Send an immediate update to the UI to show cancellation is in progress.
        # The background thread will pick up @processing_cancelled and send a :cancelled message.
        @dialog.execute_script("updateProgressOverlay('Cancelling process...', 0)")
        # Do not call finalize_nesting_process directly here; let the watcher timer handle the :cancelled message.
      end
      
      @dialog.add_action_callback("clear_nesting_cache") do |action_context|
        @nesting_cache = {}
        @last_processed_cache_key = nil
        puts "Nesting cache cleared manually"
      end

      @dialog.show
    end

    private

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
    def generate_cache_key(parts_by_material, settings)
      # Return a distinct key for empty parts to avoid accidental cache hits
      return Digest::MD5.hexdigest("EMPTY_PARTS_#{Time.now.to_i}") if parts_by_material.nil? || parts_by_material.empty?

      # Create a canonical representation of parts_by_material
      # Sort by material name, then by part properties to ensure consistent hash
      serialized_parts = parts_by_material.map do |material, parts_array|
        [material.to_s, parts_array.map do |part_entry|
          # Assuming PartType or similar objects are in part_entry[:part_type] or part_entry itself
          part_type = part_entry.is_a?(Hash) && part_entry.key?(:part_type) ? part_entry[:part_type] : part_entry
          {
            name: part_type.name.to_s,
            width: part_type.width.to_f,
            height: part_type.height.to_f,
            thickness: part_type.thickness.to_f,
            total_quantity: (part_entry[:total_quantity] || 1).to_i # Ensure quantity is part of the key
          }
        end.sort_by { |p| [p[:name], p[:width], p[:height], p[:thickness], p[:total_quantity]] }]
      end.sort_by(&:first).to_json # Sort materials by name for consistency

      # Extract only nesting-relevant settings that affect the *nesting pattern* or *outcome*
      # Create a copy of stock_materials and remove price before using for cache key
      nesting_stock_materials = if settings['stock_materials']
                                  settings['stock_materials'].transform_values do |material_data|
                                    material_data.reject { |k, _v| k == 'price' } # Remove price from the data
                                  end
                                else
                                  {}
                                end

      nesting_settings = {
        'stock_materials' => nesting_stock_materials, # Only dimensions and other non-price attributes
        'nesting_params' => settings['nesting_params'],   # Algorithm specific parameters
        'gap_size' => settings['gap_size'],
        'grain_match' => settings['grain_match'],
        'allow_rotation' => settings['allow_rotation'],
        'trim_x' => settings['trim_x'],
        'trim_y' => settings['trim_y'],
        'trim_corners' => settings['trim_corners']
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
          # Proceed directly to report generation using cached boards
          generate_report_and_show_tab(cached_boards)
          @dialog.execute_script("hideProgressOverlay()")
        end
      else
        # --- CACHE MISS ---
        # Proceed with background processing
        start_nesting_background_thread(current_cache_key) # Pass key to store results later
        start_nesting_progress_watcher
      end
    end

    # Starts the heavy nesting computation in a separate background thread
    def start_nesting_background_thread(cache_key)
      # Deep copy parts and settings to ensure thread-safety (Nester should not modify them)
      # `dup` creates a shallow copy, but for hashes of simple types or PartType instances (assumed immutable for Nester input), this is usually sufficient.
      parts_by_material_for_thread = @parts_by_material.dup
      settings_for_thread = @settings.dup

      @nesting_thread = Thread.new do
        begin
          nester = Nester.new # Nester instance per thread is fine
          boards_result = []
          
          # Pass a lambda for progress updates to Nester
          nester_progress_callback = lambda do |message, percentage|
            # Only push messages if not cancelled to avoid unnecessary queueing
            unless @processing_cancelled
              @nesting_queue.push({ type: :progress, message: message, percentage: percentage })
            end
          end

          @nesting_queue.push({ type: :progress, message: "Starting optimization...", percentage: 5 })

          # This calls the Nester with the new progress callback
          boards_result = nester.optimize_boards(parts_by_material_for_thread, settings_for_thread, nester_progress_callback)
          
          # --- Final check for cancellation before pushing complete message ---
          if @processing_cancelled
            @nesting_queue.push({ type: :cancelled })
          else
            # When all materials are processed, push the final results and the cache key
            @nesting_queue.push({ type: :complete, boards: boards_result, cache_key: cache_key })
          end

        rescue StandardError => e
          # Catch any error in the background thread and send it to the main thread
          puts "Background nesting thread error: #{e.message}\n#{e.backtrace.join("\n")}"
          @nesting_queue.push({ type: :error, message: "Nesting calculation failed: #{e.message}" })
        end
      end
    end

    # Starts a UI timer to periodically check the queue for messages from the background thread
    def start_nesting_progress_watcher
      # Check every 100 milliseconds (0.1 seconds) for smoother updates
      @nesting_watcher_timer = UI.start_timer(0.1, true) do
        process_queue_message # Process one message at a time to prevent blocking
      end
    end

    # Processes a single message from the queue on the main UI thread
    def process_queue_message
      return unless @nesting_queue # Ensure queue exists
      return if @nesting_queue.empty? # Nothing to process

      message = @nesting_queue.pop(true) # non_block=true, so it doesn't wait if empty

      case message[:type]
      when :progress
        # Ensure percentage is within 0-100 range before sending to UI
        pct = message[:percentage].clamp(0, 100)
        @dialog.execute_script("updateProgressOverlay('#{message[:message].gsub("'", "\\'")}', #{pct})")
      when :error
        finalize_nesting_process # Clean up resources
        @dialog.execute_script("hideProgressOverlay()")
        @dialog.execute_script("showError('#{message[:message].gsub("'", "\\'")}')")
      when :cancelled
        finalize_nesting_process # Clean up resources
        @dialog.execute_script("hideProgressOverlay()")
        # Assuming a `showInfoMessage` JS function exists in main.html to display non-error messages
        @dialog.execute_script("showInfoMessage('Nesting process cancelled by user.')")
      when :complete
        # Immediately update progress to 90% to show background processing is done
        @dialog.execute_script("updateProgressOverlay('All nesting calculations complete. Preparing reports...', 90)")
        
        # Clean up resources (timer & thread) as the heavy background work is done
        finalize_nesting_process 

        @boards = message[:boards] # Store the results from the background thread
        @last_processed_cache_key = message[:cache_key] # Store the key of the successful run

        # Store results in cache
        if message[:cache_key] && @boards
          @nesting_cache[message[:cache_key]] = @boards
          puts "Nesting results cached for key: #{message[:cache_key]}"
        end
        
        # Introduce a small delay to ensure the 90% progress bar updates before generating the report,
        # which might be a blocking operation.
        UI.start_timer(0.01, false) do # Use a one-shot timer to defer to next UI cycle
          generate_report_and_show_tab(@boards)
        end
      end
    rescue ThreadError # Queue might be empty if .pop(true) is called right after another .pop in a tight loop
      # Ignore, just means no message was available this tick.
    end

    # Cleans up the background thread and UI timer
    def finalize_nesting_process
      # Stop the watcher timer
      # UI.valid_timer? was introduced in SU2017. Handle older versions gracefully.
      if @nesting_watcher_timer && (defined?(UI.valid_timer?) ? UI.valid_timer?(@nesting_watcher_timer) : true)
        UI.stop_timer(@nesting_watcher_timer)
      end
      @nesting_watcher_timer = nil

      # Attempt to kill the thread if it's still alive (e.g., in case of error or explicit cancellation)
      if @nesting_thread && @nesting_thread.alive?
        @nesting_thread.kill # Forcefully terminate the thread
        @nesting_thread.join # Wait for it to terminate to prevent resource leaks
      end
      @nesting_thread = nil

      # Clear the queue for good measure
      @nesting_queue.clear if @nesting_queue
      @nesting_queue = nil

      @processing_cancelled = false # Reset cancellation flag for next process
    end

    # Generates the report data and displays the report tab in the dialog
    def generate_report_and_show_tab(boards)
      # Immediately update to 95% to show progress is still happening during report generation
      @dialog.execute_script("updateProgressOverlay('Generating reports...', 95)")

      if boards.empty?
        @dialog.execute_script("hideProgressOverlay()")
        @dialog.execute_script("showError('No boards could be generated. Please check your material settings and part dimensions.')")
        return
      end

      # Perform actual report data generation (this part might be slow depending on ReportGenerator)
      report_generator = ReportGenerator.new
      report_data = report_generator.generate_report_data(boards, @settings) # Use @settings for report generation

      # Prepare data for dialog (this part might also be slow if boards array is huge or to_h is complex)
      data = {
        diagrams: boards.map(&:to_h), # Assuming Board objects have a to_h method for UI representation
        report: report_data,
        boards: boards.map(&:to_h), # Send the board data to the UI too, as it might be needed for interactive diagrams
        original_components: @original_components,
        hierarchy_tree: @hierarchy_tree
      }

      # Final update to 100% before showing the tab
      @dialog.execute_script("updateProgressOverlay('Finalizing...', 100)")
      @dialog.execute_script("hideProgressOverlay()")
      @dialog.execute_script("showReportTab(#{data.to_json})")
    rescue StandardError => e
      @dialog.execute_script("hideProgressOverlay()")
      @dialog.execute_script("showError('Error generating report: #{e.message.gsub("'", "\\'")}')")
    end

    # ======================================================================================
    # END ASYNCHRONOUS NESTING PROCESSING
    # ======================================================================================


    def serialize_parts_by_material(parts_by_material)
      result = {}
      parts_by_material.each do |material, parts|
        result[material] = parts.map do |part_entry|
          # Handle cases where part_entry is already a hash with :part_type key
          # or if it's directly a PartType object
          part_type = part_entry.is_a?(Hash) && part_entry.key?(:part_type) ? part_entry[:part_type] : part_entry
          {
            name: part_type.name,
            width: part_type.width,
            height: part_type.height,
            thickness: part_type.thickness,
            total_quantity: part_entry[:total_quantity] || 1
          }
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

      # Clear current selection
      selection.clear

      # Find components with matching material
      matching_components = []

      if @original_components && !@original_components.empty?
        @original_components.each do |comp_data|
          # Improved material matching - handle different material name formats
          comp_material = comp_data[:material].to_s.strip
          search_material = material_name.to_s.strip

          # Direct match or partial match
          if comp_material == search_material ||
             comp_material.downcase == search_material.downcase ||
             comp_material.include?(search_material) ||
             search_material.include?(comp_material)

            # Find component by entity ID in all entities
            found_entity = find_entity_by_id(model, comp_data[:entity_id])
            if found_entity
              matching_components << found_entity
            end
          end
        end
      end

      # Add all matching components to selection at once for efficiency
      model.selection.add(matching_components)

      # Smooth zoom to selection if components found
      if matching_components.any?
        view = model.active_view
        view.zoom(matching_components)

        # Optional: Add a subtle status message
        model.set_attribute('AutoNestCut_Status', 'last_highlight', "#{matching_components.length} components highlighted")
      else
        puts "DEBUG: No components found with material: #{material_name}"
        puts "DEBUG: Available materials: #{@original_components.map{|c| c[:material]}.uniq.join(', ')}" if @original_components
        UI.messagebox("No components found with material: #{material_name}")
      end
    end

    # Helper method to find an entity by its ID recursively in the model
    def find_entity_by_id(model, entity_id)
      return nil unless entity_id

      model.entities.each do |entity|
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
      # Re-analyze current selection
      model = Sketchup.active_model
      selection = model.selection

      if selection.empty?
        @dialog.execute_script("showError('Please select components or groups to analyze for refresh.')")
        return
      end

      begin
        analyzer = ModelAnalyzer.new
        @parts_by_material = analyzer.extract_parts_from_selection(selection)
        @original_components = analyzer.get_original_components_data
        @hierarchy_tree = analyzer.get_hierarchy_tree

        if @parts_by_material.empty?
          @dialog.execute_script("showError('No valid sheet good parts found in your selection.')")
          return
        end

        # Update settings with new materials (important for material stock definitions)
        settings = Config.load_settings
        settings['stock_materials'] ||= {}
        @parts_by_material.keys.each do |material|
          unless settings['stock_materials'][material]
            settings['stock_materials'][material] = { 'width' => 2440, 'height' => 1220, 'price' => 0 }
          end
        end
        # Save settings with potentially new material defaults
        Config.save_settings(settings)

        # Send refreshed data to the dialog
        data = {
          settings: settings,
          parts_by_material: serialize_parts_by_material(@parts_by_material),
          original_components: @original_components,
          model_materials: get_model_materials,
          hierarchy_tree: @hierarchy_tree
        }
        @dialog.execute_script("receiveRefreshedData(#{data.to_json})")
      rescue => e
        @dialog.execute_script("showError('Error refreshing data: #{e.message.gsub("'", "\\'")}')")
      end
    end

    # Refreshes only the report display using the last computed boards and current settings
    def refresh_report_display_with_current_settings
      # Ensure boards are available from a previous run
      return unless @boards && !@boards.empty?

      # Load current settings, as display-only settings might have changed since last nesting
      @settings = Config.load_settings # Update @settings to ensure report generation uses latest config

      begin
        # Use cached boards and current settings to regenerate and display the report
        generate_report_and_show_tab(@boards)
      rescue => e
        @dialog.execute_script("showError('Error refreshing report display: #{e.message.gsub("'", "\\'")}')")
      end
    end

    def export_csv_report(report_data)
      model_name = Sketchup.active_model.title.empty? ? "Untitled" : Sketchup.active_model.title.gsub(/[^\w]/, '_')

      # Auto-generate filename with incrementing number
      base_name = "Cutting_List_#{model_name}"
      counter = 1

      # Cross-platform desktop path
      desktop_path = if RUBY_PLATFORM =~ /mswin|mingw|windows/
                       File.join(ENV['USERPROFILE'] || ENV['HOME'], 'Desktop')
                     else
                       File.join(ENV['HOME'], 'Desktop')
                     end

      loop do
        filename = "#{base_name}_#{counter}.csv"
        full_path = File.join(desktop_path, filename)

        unless File.exist?(full_path)
          begin
            ReportGenerator.new.export_csv(full_path, report_data)
            UI.messagebox("Cut list exported to Desktop: #{filename}")
            return
          rescue => e
            UI.messagebox("Error exporting CSV: #{e.message}")
            return
          end
        end

        counter += 1
      end
    end
  end
end
