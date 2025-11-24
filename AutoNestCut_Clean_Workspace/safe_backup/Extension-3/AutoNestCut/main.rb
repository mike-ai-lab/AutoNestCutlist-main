# frozen_string_literal: true

require 'sketchup.rb'

# Check SketchUp version compatibility
if Sketchup.version.to_i < 20
  UI.messagebox("AutoNestCut requires SketchUp 2020 or later. Current version: #{Sketchup.version}")
  return # Important: exit if not compatible
end

# Load licensing system first (these are typically outside the main module if they define top-level modules like `LicenseManager`)
begin
  require_relative '../lib/LicenseManager/license_manager'
  require_relative '../lib/LicenseManager/trial_manager'
  require_relative '../lib/LicenseManager/license_dialog'
  puts "Licensing system loaded successfully"
rescue LoadError => e
  puts "Warning: Could not load licensing system: #{e.message}"
end

# Define the main module for your extension
module AutoNestCut

  # Define constants for the extension (good practice for registration)
  EXTENSION_NAME = 'Auto Nest Cut'.freeze
  EXTENSION_VERSION = '1.0.0'.freeze # Placeholder, update as needed
  EXTENSION_DESCRIPTION = 'Automated nesting and cut list generation for sheet goods.'.freeze
  EXTENSION_CREATOR = 'Muhamad Shkeir'.freeze # Assuming creator from email
  EXTENSION_ID = "autonestcut.extension".freeze # <--- THIS IS THE MISSING LINE!

  # Get the path to the current directory where this file resides
  PATH_ROOT = File.dirname(__FILE__).freeze

  # --- ALL CORE EXTENSION FILES MUST BE REQUIRED HERE ---
  # These are crucial files that define core components.
  # Ensure these paths are correct relative to THIS main.rb.
  
  require_relative 'compatibility'
  require_relative 'materials_database'
  require_relative 'config'
  
  # Models
  require_relative 'models/part'
  require_relative 'models/board'
  require_relative 'models/facade_surface'
  require_relative 'models/cladding_preset'
  
  # Processors
  require_relative 'processors/model_analyzer'
  require_relative 'processors/nester'
  require_relative 'processors/facade_analyzer'
  require_relative 'processors/component_cache'
  require_relative 'processors/async_processor' # This one was problematic!
  
  # UI components
  require_relative 'ui/dialog_manager'
  require_relative 'ui/progress_dialog'
  
  # Exporters
  require_relative 'exporters/diagram_generator'
  require_relative 'exporters/report_generator'
  require_relative 'exporters/facade_reporter'
  
  # Other top-level files
  require_relative 'scheduler'
  require_relative 'supabase_client'
  require_relative 'util'

  # --- END OF CORE EXTENSION FILE REQUIREMENTS ---

  def self.show_documentation
    html_file = File.join(__dir__, 'ui', 'html', 'documentation.html')

    if File.exist?(html_file)
      dialog = UI::HtmlDialog.new(
        dialog_title: "AutoNestCut Documentation",
        preferences_key: "AutoNestCut_Documentation",
        scrollable: true,
        resizable: true,
        width: 1000,
        height: 700,
        left: 100,
        top: 100,
        min_width: 800,
        min_height: 600,
        style: UI::HtmlDialog::STYLE_DIALOG
      )

      dialog.set_file(html_file)
      dialog.show
    else
      UI.messagebox("Documentation file not found at: #{html_file}")
    end
  end

  def self.open_purchase_page
    purchase_url = "https://autonestcutserver-moeshks-projects.vercel.app"
    UI.openURL(purchase_url)
  end

  def self.run_extension_feature
    # Check license before allowing extension use
    if defined?(AutoNestCut::LicenseManager) && defined?(::LicenseManager) # Check both outer and inner (if applicable)
      unless ::LicenseManager.has_valid_license? # Assume LicenseManager is top-level for direct call
        ::LicenseDialog.show_license_options
        return unless ::LicenseManager.has_valid_license?
      end

      # Start trial countdown if using trial license
      if defined?(::TrialManager)
        ::TrialManager.start_trial_countdown
      end
    end

    model = Sketchup.active_model
    selection = model.selection

    if selection.empty?
      UI.messagebox("Please select components or groups to analyze for AutoNestCut.")
      return
    end

    begin
      # Initialize async processor
      # Now AsyncProcessor is defined within AutoNestCut, so no NameError.
      async_processor = AutoNestCut::AsyncProcessor.new
      
      # Check cache first
      cached = AutoNestCut::ComponentCache.get_cached_analysis(selection) # Add AutoNestCut:: prefix
      
      if cached
        dialog_manager = AutoNestCut::UIDialogManager.new # Add AutoNestCut:: prefix
        dialog_manager.show_config_dialog(cached[:parts_by_material], cached[:original_components], cached[:hierarchy_tree])
      else
        analyzer = AutoNestCut::ModelAnalyzer.new # Add AutoNestCut:: prefix
        
        part_types_by_material_and_quantities = analyzer.analyze_selection(selection)
        
        original_components = analyzer.get_original_components_data
        hierarchy_tree = analyzer.get_hierarchy_tree

        if part_types_by_material_and_quantities.empty?
          UI.messagebox("No valid sheet good parts found in your selection for AutoNestCut.")
          return
        end
        
        # Cache the results
        AutoNestCut::ComponentCache.cache_analysis(selection, part_types_by_material_and_quantities, original_components, hierarchy_tree) # Add AutoNestCut:: prefix

        dialog_manager = AutoNestCut::UIDialogManager.new # Add AutoNestCut:: prefix
        dialog_manager.show_config_dialog(part_types_by_material_and_quantities, original_components, hierarchy_tree)
      end

    rescue => e
      UI.messagebox("An error occurred during part extraction:\n#{e.message}\n#{e.backtrace.join("\n")}")
      puts "ERROR: An error occurred during part extraction: #{e.class}: #{e.message}"
      puts e.backtrace.join("\n")
    end
  end

  def self.show_scheduler
    html_file = File.join(__dir__, 'ui', 'html', 'scheduler.html')
    
    dialog = UI::HtmlDialog.new(
      dialog_title: "Scheduled Exports",
      preferences_key: "AutoNestCut_Scheduler",
      scrollable: true,
      resizable: true,
      width: 600,
      height: 500
    )
    
    dialog.set_file(html_file)
    
    # Add callbacks for scheduler operations
    dialog.add_action_callback('add_scheduled_task') do |context, name, hour, filters, format, email|
      AutoNestCut::Scheduler.add_task(name, hour, JSON.parse(filters), format, email) # Add AutoNestCut:: prefix
    end
    
    dialog.add_action_callback('get_scheduled_tasks') do |context|
      tasks = AutoNestCut::Scheduler.load_tasks # Add AutoNestCut:: prefix
      dialog.execute_script("displayTasks(#{tasks.to_json})")
    end
    
    dialog.add_action_callback('delete_scheduled_task') do |context, task_id|
      tasks = AutoNestCut::Scheduler.load_tasks # Add AutoNestCut:: prefix
      tasks.reject! { |t| t[:id] == task_id }
      AutoNestCut::Scheduler.save_tasks(tasks) # Add AutoNestCut:: prefix
    end
    
    dialog.show
  end

  def self.show_facade_calculator
    model = Sketchup.active_model
    selection = model.selection

    if selection.empty?
      UI.messagebox("Please select facade surfaces (faces) to analyze for material calculation.")
      return
    end

    html_file = File.join(__dir__, 'ui', 'html', 'facade_config.html')
    
    dialog = UI::HtmlDialog.new(
      dialog_title: "Facade Materials Calculator",
      preferences_key: "AutoNestCut_Facade",
      scrollable: true,
      resizable: true,
      width: 900,
      height: 700
    )
    
    dialog.set_file(html_file)
    
    # Initialize facade analyzer
    # Now FacadeAnalyzer is defined within AutoNestCut, so no NameError.
    analyzer = AutoNestCut::FacadeAnalyzer.new
    surfaces = analyzer.analyze_selection(selection) # Assuming analyze_selection is defined in FacadeAnalyzer
    
    # Add callbacks for facade operations
    dialog.add_action_callback('analyze_selected_surfaces') do |context|
      surface_info = {
        count: surfaces.length,
        area: surfaces.sum(&:area_m2).round(2),
        types: AutoNestCut.get_surface_types_summary(surfaces) # Call helper from AutoNestCut module
      }
      dialog.execute_script("updateSurfaceInfo(#{surface_info.to_json})")
    end
    
    dialog.add_action_callback('get_facade_presets') do |context|
      presets = AutoNestCut.load_facade_presets # Call helper from AutoNestCut module
      dialog.execute_script("displayPresets(#{presets.to_json})")
    end
    
    dialog.add_action_callback('calculate_facade_materials') do |context, settings_json|
      settings = JSON.parse(settings_json)
      preset = AutoNestCut.find_preset_by_name(settings['preset']) # Call helper from AutoNestCut module
      
      if preset
        quantities = analyzer.calculate_quantities(surfaces, preset)
        surface_breakdown = analyzer.generate_surface_breakdown(surfaces)
        
        reporter = AutoNestCut::FacadeReporter.new # Add AutoNestCut:: prefix
        report_data = reporter.generate_facade_report(quantities, surface_breakdown, settings)
        
        dialog.execute_script("displayResults(#{report_data[:cost_estimation].to_json})")
        @last_facade_report = report_data
      end
    end
    
    dialog.add_action_callback('export_facade_report') do |context|
      if @last_facade_report
        filename = UI.savepanel("Save Facade Materials Report", "", "facade_materials.csv")
        if filename
          reporter = AutoNestCut::FacadeReporter.new # Add AutoNestCut:: prefix
          reporter.export_facade_csv(filename, @last_facade_report)
          UI.messagebox("Facade materials report exported to: #{filename}")
        end
      end
    end
    
    dialog.show
  end

  def self.setup_ui
    puts "TRACE: AutoNestCut.setup_ui called."
    # Use Sketchup::file_loaded? for robustness in SketchUp's extension system
    # This line uses EXTENSION_ID.
    unless Sketchup::file_loaded?("#{EXTENSION_ID}/#{File.basename(__FILE__)}") # Use EXTENSION_ID to avoid conflicts
      puts "TRACE: AutoNestCut.setup_ui: file_loaded? is false, setting up UI."

      # --- MENU SETUP ---
      menu = UI.menu('Extensions')
      puts "TRACE: setup_ui: Got 'Extensions' menu object: #{menu.inspect}"
      
      autonest_menu = menu.add_submenu(EXTENSION_NAME) # Use constant for name
      puts "TRACE: setup_ui: Added submenu '#{EXTENSION_NAME}'. Submenu object: #{autonest_menu.inspect}"

      autonest_menu.add_item('Generate Cut List') { run_extension_feature }
      puts "TRACE: setup_ui: Added 'Generate Cut List' menu item."
      
      autonest_menu.add_separator
      puts "TRACE: setup_ui: Added separator 1."
      
      autonest_menu.add_item('Facade Materials Calculator') { AutoNestCut.show_facade_calculator }
      puts "TRACE: setup_ui: Added 'Facade Materials Calculator' menu item."
      
      autonest_menu.add_separator
      puts "TRACE: setup_ui: Added separator 2."
      
      autonest_menu.add_item('Scheduled Exports') { AutoNestCut.show_scheduler }
      puts "TRACE: setup_ui: Added 'Scheduled Exports' menu item."
      
      autonest_menu.add_separator
      puts "TRACE: setup_ui: Added separator 3."
      
      autonest_menu.add_item('Documentation - How to...') { AutoNestCut.show_documentation }
      puts "TRACE: setup_ui: Added 'Documentation - How to...' menu item."

      # Corrected logic for LicenseManager
      if defined?(::LicenseManager) && defined?(::LicenseDialog) && defined?(::TrialManager) # Check top-level definitions
        autonest_menu.add_separator
        autonest_menu.add_item('Purchase License') { AutoNestCut.open_purchase_page }
        autonest_menu.add_item('License Info') { ::LicenseDialog.show } # Call top-level LicenseDialog
        autonest_menu.add_item('Trial Status') { ::LicenseDialog.show_trial_status } # Call top-level LicenseDialog
        puts "TRACE: setup_ui: Added License menu items."
      else
        puts "TRACE: setup_ui: ⚠️ LicenseDialog not defined, skipping license menu."
      end

      # --- TOOLBAR SETUP ---
      toolbar = UI::Toolbar.new(EXTENSION_NAME) # Use constant for name
      puts "TRACE: setup_ui: Created toolbar '#{EXTENSION_NAME}'. Toolbar object: #{toolbar.inspect}"
      
      cmd = UI::Command.new(EXTENSION_NAME) { run_extension_feature }
      cmd.tooltip = 'Generate optimized cut lists and nesting diagrams for sheet goods'
      cmd.status_bar_text = 'AutoNestCut - Automated nesting for sheet goods'
      puts "TRACE: setup_ui: Created UI::Command for toolbar."

      # Use PATH_ROOT for icon path, which is defined correctly within the module
      icon_path = File.join(PATH_ROOT, 'resources', 'icon.png')
      if File.exist?(icon_path)
        cmd.small_icon = icon_path
        cmd.large_icon = icon_path
        puts "TRACE: setup_ui: ✅ AutoNestCut icon path: #{icon_path}, exists: #{File.exist?(icon_path)}"
      else
        puts "TRACE: setup_ui: ⚠️ AutoNestCut icon not found at: #{icon_path}. Command will not have icon."
      end

      toolbar.add_item(cmd)
      puts "TRACE: setup_ui: Added command to toolbar." 
      
      toolbar.show
      puts "TRACE: setup_ui: Called toolbar.show."

      puts "TRACE: AutoNestCut.setup_ui: UI setup complete."
      # Mark this specific file (main.rb) as loaded for UI purposes
      Sketchup::file_loaded("#{EXTENSION_ID}/#{File.basename(__FILE__)}")
    else
      puts "TRACE: AutoNestCut.setup_ui: UI already loaded, skipping setup."
    end
  end

  # Start background scheduler timer
  def self.start_scheduler_timer
    puts "TRACE: AutoNestCut.start_scheduler_timer called."
    # Use a module instance variable for the timer ID, not a class variable @@
    return if defined?(@scheduler_timer) && @scheduler_timer # Check for existence and if it's not nil/false
    
    @scheduler_timer = UI.start_timer(300, true) do # Check every 5 minutes
      begin
        AutoNestCut::Scheduler.check_due_tasks # Add AutoNestCut:: prefix
      rescue => e
        puts "Scheduler error: #{e.message}"
      end
    end
    puts "TRACE: AutoNestCut.start_scheduler_timer: Timer setup complete."
    puts "✅ Scheduler timer started"
  end

  # Helper methods for facade calculator
  def self.get_surface_types_summary(surfaces)
    types = surfaces.group_by(&:orientation)
    summary = types.keys.join(', ')
    summary.empty? ? 'Mixed' : summary.capitalize
  end
  
  def self.load_facade_presets
    # For now, return built-in presets. Later can load from V121_LAYOUT presets
    [
      {
        name: 'Standard Brick',
        dimensions: '215×65×20mm',
        pattern: 'Running Bond'
      },
      {
        name: 'Large Stone',
        dimensions: '400×200×30mm', 
        pattern: 'Stack Bond'
      },
      {
        name: 'Small Tiles',
        dimensions: '200×200×10mm',
        pattern: 'Grid'
      }
    ]
  end
  
  def self.find_preset_by_name(name)
    # Create a basic preset for testing
    preset_data = {
      'length' => '215',
      'height' => '65', 
      'thickness' => 20.0,
      'joint_length' => 10.0,
      'joint_width' => 10.0,
      'pattern_type' => 'running_bond',
      'color_name' => name
    }
    AutoNestCut::CladdingPreset.new(preset_data, name) # Add AutoNestCut:: prefix
  end

  # Module initialization block
  # Using a module instance variable for the loaded flag to avoid global/class variable issues.
  # This flag belongs to the module object itself.
  unless @loaded_flag_for_main_rb
    @loaded_flag_for_main_rb = true
    timestamp = Time.now.strftime("%H:%M:%S")
    puts "TRACE: AutoNestCut Module initialization block running [#{timestamp}]"
    
    setup_ui
    start_scheduler_timer
    
    # Corrected conditional and calls for top-level LicenseManager
    if defined?(::LicenseManager) && defined?(::TrialManager)
      unless ::LicenseManager.has_valid_license?
        ::LicenseManager.check_existing_trial(false)
      end
      
      if ::TrialManager.trial_active?
        ::TrialManager.start_trial_countdown
      end
    end
    puts "TRACE: AutoNestCut Module initialization block finished."
  else
    puts "TRACE: AutoNestCut Module @loaded_flag_for_main_rb already true, skipping initialization."
  end

end # End of module AutoNestCut

# Register the extension with SketchUp
# This makes it appear in the Extension Manager and handles automatic loading.
# For your dev workflow, this is often commented out, but it's good practice.
# Sketchup.register_extension(
#   SketchupExtension.new(AutoNestCut::EXTENSION_NAME, File.join(File.dirname(__FILE__), 'main.rb')),
#   AutoNestCut::EXTENSION_ID # Unique ID for extension management
# )

puts "TRACE: main.rb finished executing."
