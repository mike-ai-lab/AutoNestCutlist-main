# frozen_string_literal: true

require 'sketchup.rb'

# Check SketchUp version compatibility
if Sketchup.version.to_i < 20
  UI.messagebox("AutoNestCut requires SketchUp 2020 or later. Current version: #{Sketchup.version}")
  return
end

# Load licensing system first
begin
  require_relative '../lib/LicenseManager/license_manager'
  require_relative '../lib/LicenseManager/trial_manager'
  require_relative '../lib/LicenseManager/license_dialog'
  puts "Licensing system loaded successfully"
rescue LoadError => e
  puts "Warning: Could not load licensing system: #{e.message}"
end

# Core extension files
require_relative 'compatibility'
require_relative 'materials_database'
require_relative 'config'
require_relative 'models/part'
require_relative 'models/board'
require_relative 'models/facade_surface'
require_relative 'models/cladding_preset'
require_relative 'processors/model_analyzer'
require_relative 'processors/nester'
require_relative 'processors/facade_analyzer'
require_relative 'processors/component_cache'

require_relative 'ui/dialog_manager'
require_relative 'ui/progress_dialog'
require_relative 'processors/async_processor'
require_relative 'exporters/diagram_generator'
require_relative 'exporters/report_generator'
require_relative 'exporters/facade_reporter'
require_relative 'scheduler'
require_relative 'supabase_client'
require_relative 'util'

module AutoNestCut

  # Utility method for cache-busting HTML dialogs
  def self.set_html_with_cache_busting(dialog, html_file_path)
    cache_buster = Time.now.to_i.to_s
    
    # Read the HTML content
    html_content = File.read(html_file_path, encoding: 'UTF-8')
    
    # Replace relative paths with cache-busted absolute paths
    html_content.gsub!(/(src|href)="(?!https?:\/\/)([^"]*?)"/) do |match|
      type = $1 # 'src' or 'href'
      relative_path = $2 # The actual path
      
      # Skip if it's already an absolute URL or data URL
      next match if relative_path.start_with?('http', 'data:', '//')
      
      # Construct absolute path from the directory of the HTML file
      absolute_path = File.join(File.dirname(html_file_path), relative_path)
      absolute_url = "file:///#{File.expand_path(absolute_path).gsub('\\', '/')}"
      
      # Append cache buster
      "#{type}=\"#{absolute_url}?v=#{cache_buster}\""
    end
    
    # Set the modified HTML content
    dialog.set_html(html_content)
  end

  # Define constants for the extension (good practice for registration)
  EXTENSION_NAME = 'Auto Nest Cut'.freeze
  EXTENSION_VERSION = '1.0.0'.freeze # Placeholder, update as needed
  EXTENSION_DESCRIPTION = 'Automated nesting and cut list generation for sheet goods.'.freeze
  EXTENSION_CREATOR = 'Muhamad Shkeir'.freeze # Assuming creator from email

  # Get the path to the current directory where this file resides
  PATH_ROOT = File.dirname(__FILE__).freeze

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

      AutoNestCut.set_html_with_cache_busting(dialog, html_file)
      dialog.show
    else
      UI.messagebox("Documentation file not found at: #{html_file}")
    end
  end

  def self.open_purchase_page
    purchase_url = "https://autonestcutserver-moeshks-projects.vercel.app"
    UI.openURL(purchase_url)
  end

  # This method is the primary entry point for the extension's main functionality.
  # It's defined directly as a module method (`self.method_name`) for clarity and robustness.
  # Renamed from `activate_extension` to `run_extension_feature` to avoid confusion
  # with SketchUp's internal terminology for extension activation.
  def self.run_extension_feature
    # Check license before allowing extension use
    if defined?(AutoNestCut::LicenseManager)
      unless AutoNestCut::LicenseManager.has_valid_license?
        AutoNestCut::LicenseDialog.show_license_options
        return unless AutoNestCut::LicenseManager.has_valid_license?
      end

      # Start trial countdown if using trial license
      if defined?(AutoNestCut::TrialManager)
        AutoNestCut::TrialManager.start_trial_countdown
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
      async_processor = AsyncProcessor.new
      
      # Check cache first
      cached = ComponentCache.get_cached_analysis(selection)
      
      if cached
        dialog_manager = UIDialogManager.new
        dialog_manager.show_config_dialog(cached[:parts_by_material], cached[:original_components], cached[:hierarchy_tree])
      else
        analyzer = ModelAnalyzer.new
        
        # --- FIX: Changed method call from extract_parts_from_selection to analyze_selection ---
        part_types_by_material_and_quantities = analyzer.analyze_selection(selection)
        # --- END FIX ---
        
        original_components = analyzer.get_original_components_data
        hierarchy_tree = analyzer.get_hierarchy_tree

        if part_types_by_material_and_quantities.empty?
          UI.messagebox("No valid sheet good parts found in your selection for AutoNestCut.")
          return
        end
        
        # Cache the results
        ComponentCache.cache_analysis(selection, part_types_by_material_and_quantities, original_components, hierarchy_tree)

        dialog_manager = UIDialogManager.new
        dialog_manager.show_config_dialog(part_types_by_material_and_quantities, original_components, hierarchy_tree)
      end

    rescue => e
      UI.messagebox("An error occurred during part extraction:\n#{e.message}")
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
    
    AutoNestCut.set_html_with_cache_busting(dialog, html_file)
    
    # Add callbacks for scheduler operations
    dialog.add_action_callback('add_scheduled_task') do |context, name, hour, filters, format, email|
      Scheduler.add_task(name, hour, JSON.parse(filters), format, email)
    end
    
    dialog.add_action_callback('get_scheduled_tasks') do |context|
      tasks = Scheduler.load_tasks
      dialog.execute_script("displayTasks(#{tasks.to_json})")
    end
    
    dialog.add_action_callback('delete_scheduled_task') do |context, task_id|
      tasks = Scheduler.load_tasks
      tasks.reject! { |t| t[:id] == task_id }
      Scheduler.save_tasks(tasks)
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
    
    AutoNestCut.set_html_with_cache_busting(dialog, html_file)
    
    # Initialize facade analyzer
    analyzer = FacadeAnalyzer.new
    surfaces = analyzer.analyze_selection(selection)
    
    # Add callbacks for facade operations
    dialog.add_action_callback('analyze_selected_surfaces') do |context|
      surface_info = {
        count: surfaces.length,
        area: surfaces.sum(&:area_m2).round(2),
        types: get_surface_types_summary(surfaces)
      }
      dialog.execute_script("updateSurfaceInfo(#{surface_info.to_json})")
    end
    
    dialog.add_action_callback('get_facade_presets') do |context|
      presets = load_facade_presets
      dialog.execute_script("displayPresets(#{presets.to_json})")
    end
    
    dialog.add_action_callback('calculate_facade_materials') do |context, settings_json|
      settings = JSON.parse(settings_json)
      preset = find_preset_by_name(settings['preset'])
      
      if preset
        quantities = analyzer.calculate_quantities(surfaces, preset)
        surface_breakdown = analyzer.generate_surface_breakdown(surfaces)
        
        reporter = FacadeReporter.new
        report_data = reporter.generate_facade_report(quantities, surface_breakdown, settings)
        
        dialog.execute_script("displayResults(#{report_data[:cost_estimation].to_json})")
        @last_facade_report = report_data
      end
    end
    
    dialog.add_action_callback('export_facade_report') do |context|
      if @last_facade_report
        filename = UI.savepanel("Save Facade Materials Report", "", "facade_materials.csv")
        if filename
          reporter = FacadeReporter.new
          reporter.export_facade_csv(filename, @last_facade_report)
          UI.messagebox("Facade materials report exported to: #{filename}")
        end
      end
    end
    
    dialog.show
  end

  def self.setup_ui
    unless file_loaded?("#{__FILE__}-ui")
      # Create main menu
      menu = UI.menu('Extensions')
      autonest_menu = menu.add_submenu(EXTENSION_NAME) # Use constant for name

      # Call the renamed primary function
      autonest_menu.add_item('Generate Cut List') { run_extension_feature }
      autonest_menu.add_separator
      autonest_menu.add_item('Facade Materials Calculator') { AutoNestCut.show_facade_calculator }
      autonest_menu.add_separator
      autonest_menu.add_item('Scheduled Exports') { AutoNestCut.show_scheduler }
      autonest_menu.add_separator
      autonest_menu.add_item('Documentation - How to...') { AutoNestCut.show_documentation }

      # Add license menu if licensing system is available
      if defined?(AutoNestCut::LicenseDialog)
        autonest_menu.add_separator
        autonest_menu.add_item('Purchase License') { AutoNestCut.open_purchase_page }
        autonest_menu.add_item('License Info') { AutoNestCut::LicenseDialog.show }
        autonest_menu.add_item('Trial Status') { AutoNestCut::LicenseDialog.show_trial_status }
      else
        puts "⚠️ LicenseDialog not defined"
      end

      # Create toolbar with icon
      toolbar = UI::Toolbar.new(EXTENSION_NAME) # Use constant for name
      # Call the renamed primary function
      cmd = UI::Command.new(EXTENSION_NAME) { run_extension_feature }
      cmd.tooltip = 'Generate optimized cut lists and nesting diagrams for sheet goods'
      cmd.status_bar_text = 'AutoNestCut - Automated nesting for sheet goods'

      # Set icons for toolbar
      icon_path = File.join(__dir__, 'resources', 'icon.png')
      if File.exist?(icon_path)
        cmd.small_icon = icon_path
        cmd.large_icon = icon_path
        puts "✅ AutoNestCut icon loaded: #{icon_path}"
      else
        puts "⚠️ AutoNestCut icon not found: #{icon_path}"
      end

      toolbar.add_item(cmd)
      toolbar.show

      file_loaded("#{__FILE__}-ui")
    end
  end

  # Start background scheduler timer
  def self.start_scheduler_timer
    return if defined?(@@scheduler_timer)
    
    @@scheduler_timer = UI.start_timer(300, true) do # Check every 5 minutes
      begin
        Scheduler.check_due_tasks
      rescue => e
        puts "Scheduler error: #{e.message}"
      end
    end
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
    CladdingPreset.new(preset_data, name)
  end

  # Module initialization
  unless defined?(@@loaded)
    @@loaded = true
    timestamp = Time.now.strftime("%H:%M:%S")
    puts "✅ AutoNestCut Module Loaded [#{timestamp}]"
    
    unless defined?(AutoNestCutPowerLoader)
      setup_ui
      start_scheduler_timer
      
      if defined?(AutoNestCut::LicenseManager) && defined?(AutoNestCut::TrialManager)
        unless AutoNestCut::LicenseManager.has_valid_license?
          AutoNestCut::LicenseManager.check_existing_trial(false)
        end
        
        if AutoNestCut::TrialManager.trial_active?
          AutoNestCut::TrialManager.start_trial_countdown
        end
      end
    end
  end

end # End of module AutoNestCut
