module AutoNestCut
  class AsyncProcessor
    
    BATCH_SIZE_ANALYZER = 50
    BATCH_SIZE_NESTER = 10
    ASYNC_THRESHOLD = 21
    MAX_PROCESSING_TIME = 300 # 5 minutes timeout
    
    def initialize
      @progress_dialog = nil
      @start_time = nil
      @cancelled = false
    end
    
    def should_use_async?(selection)
      component_count = count_total_components(selection)
      component_count >= ASYNC_THRESHOLD
    end
    
    def process_with_progress(selection, settings, &completion_callback)
      component_count = count_total_components(selection)
      
      if should_use_async?(selection)
        process_async(selection, settings, component_count, &completion_callback)
      else
        process_sync(selection, settings, &completion_callback)
      end
    end
    
    private
    
    def count_total_components(selection)
      count = 0
      selection.each do |entity|
        count += count_components_recursive(entity)
      end
      count
    end
    
    def count_components_recursive(entity)
      count = 0
      
      if entity.is_a?(Sketchup::ComponentInstance)
        count = 1
        entity.definition.entities.each do |child|
          count += count_components_recursive(child)
        end
      elsif entity.is_a?(Sketchup::Group)
        entity.entities.each do |child|
          count += count_components_recursive(child)
        end
      end
      
      count
    end
    
    def process_async(selection, settings, component_count, &completion_callback)
      @start_time = Time.now
      @cancelled = false
      @step = 0
      @total_steps = 4
      
      # Show progress dialog
      @progress_dialog = ProgressDialog.new
      @progress_dialog.show("Processing Components", component_count)
      
      # Start processing in chunks with timers
      @selection = selection
      @settings = settings
      @completion_callback = completion_callback
      
      start_chunked_processing
    end
    
    def process_sync(selection, settings, &completion_callback)
      begin
        analyzer = ModelAnalyzer.new
        parts_by_material = analyzer.extract_parts_from_selection(selection)
        original_components = analyzer.get_original_components_data
        hierarchy_tree = analyzer.get_hierarchy_tree
        
        if parts_by_material.empty?
          UI.messagebox("No valid sheet good parts found in your selection.")
          return
        end
        
        nester = Nester.new
        boards = nester.optimize_boards(parts_by_material, settings)
        
        result = {
          parts_by_material: parts_by_material,
          original_components: original_components,
          hierarchy_tree: hierarchy_tree,
          boards: boards
        }
        
        completion_callback.call(result) if completion_callback
        
      rescue => e
        UI.messagebox("Processing error: #{e.message}")
        puts "Sync processing error: #{e.message}"
      end
    end
    
    def start_chunked_processing
      @step = 1
      update_progress(@step, @total_steps, "Initializing...", 5)
      
      @analyzer = ModelAnalyzer.new
      
      UI.start_timer(0.05, false) { process_step_2 }
    end
    
    def process_step_2
      return if check_cancellation
      
      @step = 2
      update_progress(@step, @total_steps, "Analyzing components...", 15)
      
      UI.start_timer(0.05, false) do
        begin
          @parts_by_material = @analyzer.extract_parts_from_selection(@selection)
          
          if @parts_by_material.empty?
            @progress_dialog.close
            UI.messagebox("No valid sheet good parts found.")
            return
          end
          
          @original_components = @analyzer.get_original_components_data
          @hierarchy_tree = @analyzer.get_hierarchy_tree
          
          UI.start_timer(0.05, false) { process_step_3 }
        rescue => e
          @progress_dialog.close
          UI.messagebox("Analysis error: #{e.message}")
        end
      end
    end
    
    def process_step_3
      return if check_cancellation
      
      @step = 3
      update_progress(@step, @total_steps, "Optimizing layouts...", 60)
      
      UI.start_timer(0.05, false) do
        begin
          nester = Nester.new
          @boards = nester.optimize_boards(@parts_by_material, @settings)
          
          UI.start_timer(0.05, false) { process_step_4 }
        rescue => e
          @progress_dialog.close
          UI.messagebox("Nesting error: #{e.message}")
        end
      end
    end
    
    def process_step_4
      return if check_cancellation
      
      @step = 4
      update_progress(@step, @total_steps, "Finalizing...", 100)
      
      UI.start_timer(0.1, false) do
        @progress_dialog.close
        
        result = {
          parts_by_material: @parts_by_material,
          original_components: @original_components,
          hierarchy_tree: @hierarchy_tree,
          boards: @boards
        }
        
        @completion_callback.call(result) if @completion_callback
      end
    end
    
    def check_cancellation
      if @progress_dialog && @progress_dialog.cancelled?
        @progress_dialog.close
        true
      else
        false
      end
    end
    

    
    def update_progress(step, total_steps, message, percentage)
      return unless @progress_dialog
      
      @progress_dialog.update_progress(step, total_steps, message, percentage)
      
      # Allow UI to update
      sleep(0.01)
    end
    

  end
end