# C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace/Extension/POWER_LOADER.rb

# AutoNestCut Extension Development Reloader
require 'sketchup'

# Define the module for the core logic
module AutoNestCutPowerLoader
  # TOOLBAR_NAMES_TO_CLEAN must be a constant defined at module level.
  # You must populate this array with the exact string names of all toolbars your extension creates.
  TOOLBAR_NAMES_TO_CLEAN = [
    "AutoNestCut Toolbar", # Add actual names of your toolbars here
    # "AutoNestCut - Some Other Toolbar",
  ].freeze

  # List of common patterns to identify extension files in $LOADED_FEATURES.
  LOADED_FEATURES_PATTERNS = [
    /AutoNestCut/i,       # Matches "AutoNestCut", "autonestcut", etc.
    /license_manager/i,
    /rgloader/i,
    /jwt/i,
    /main\.rb/i,          # Matches main.rb explicitly
    /power_loader\.rb/i   # Include the power_loader itself to ensure a clean slate
  ].freeze

  # @ext_path_override will store the absolute path to the 'Extension' folder.
  @ext_path_override = nil

  def self.set_extension_path(path)
    @ext_path_override = File.expand_path(path)
    puts "DEBUG: AutoNestCutPowerLoader extension path set to: #{@ext_path_override}"
  end

  def self.current_ext_path
    @ext_path_override || (
      warn "WARN: AutoNestCutPowerLoader: Extension path not explicitly set. Inferring from __FILE__. Please use `reload_autonestcut(\"...\")` for explicit control."
      File.expand_path(File.dirname(__FILE__))
    )
  end

  def self.cleanup
    puts "TRACE: PowerLoader cleanup started."

    UI.start_timer(0.1, false) do
      if defined?(UI) && defined?(UI::Toolbar) && UI::Toolbar.respond_to?(:get_toolbar)
        TOOLBAR_NAMES_TO_CLEAN.each do |toolbar_name|
          begin
            toolbar = UI::Toolbar.get_toolbar(toolbar_name)
            if toolbar
              toolbar.close
              puts "TRACE: PowerLoader: Closed toolbar '#{toolbar_name}'."
            else
              puts "TRACE: PowerLoader: Toolbar '#{toolbar_name}' not found or already closed."
            end
          rescue => e
            puts "WARN: PowerLoader: Error closing toolbar '#{toolbar_name}': #{e.message}"
            puts e.backtrace.join("\n") if $DEBUG
          end
        end
      else
        puts "WARN: PowerLoader: UI::Toolbar not fully available for cleanup during delayed check. Skipping toolbar operations."
      end
    end

    puts "TRACE: PowerLoader: Menu item cleanup is implicit with module reload or requires explicit references (not directly supported by API for removal)."

    if Object.const_defined?(:AutoNestCut)
      ::AutoNestCut.constants.each do |const_name|
        begin
          if ::AutoNestCut.const_defined?(const_name)
            ::AutoNestCut.send(:remove_const, const_name)
            puts "TRACE: PowerLoader: Removed AutoNestCut::#{const_name}."
          end
        rescue => e
          puts "WARN: PowerLoader: Could not remove AutoNestCut::#{const_name}: #{e.class}: #{e.message}"
          puts e.backtrace.join("\n") if $DEBUG
        end
      end
      Object.send(:remove_const, :AutoNestCut)
      puts "TRACE: PowerLoader: Removed top-level AutoNestCut module."
    else
      puts "TRACE: PowerLoader: AutoNestCut module not found, no need to remove."
    end
    
    initial_loaded_features_count = $LOADED_FEATURES.size
    $LOADED_FEATURES.delete_if do |f|
      LOADED_FEATURES_PATTERNS.any? { |pattern| f.match?(pattern) }
    end
    removed_features_count = initial_loaded_features_count - $LOADED_FEATURES.size
    puts "TRACE: PowerLoader: Cleared #{removed_features_count} relevant entries from $LOADED_FEATURES."

    initial_sketchup_loaded_count = $loaded_files.size
    $loaded_files.delete_if do |f|
      normalized_f = f.gsub('\\', '/')
      LOADED_FEATURES_PATTERNS.any? { |pattern| normalized_f.match?(pattern) }
    end
    removed_sketchup_loaded_count = initial_sketchup_loaded_count - $loaded_files.size
    puts "TRACE: PowerLoader: Cleared #{removed_sketchup_loaded_count} entries from SketchUp's internal $loaded_files cache."

    if Object.const_defined?(:AutoNestCut) && ::AutoNestCut.class_variable_defined?(:@@loaded)
      ::AutoNestCut.class_variable_set(:@@loaded, false)
      puts "TRACE: PowerLoader: Explicitly set AutoNestCut::@@loaded to false (if module still exists)."
    else
      puts "TRACE: PowerLoader: AutoNestCut::@@loaded flag not defined or module not found, no need to unset."
    end

    puts "TRACE: PowerLoader cleanup finished."
  end

  def self.load_extension
    puts "TRACE: PowerLoader load_extension started."
    
    current_path = self.current_ext_path
    puts "DEBUG: EXT_PATH (using explicit path) resolved to: #{current_path}"

    main_file = File.join(current_path, "AutoNestCut", "main.rb")
    
    if File.exist?(main_file)
      load main_file, true
      puts "TRACE: PowerLoader: Loaded #{main_file}."
    else
      UI.messagebox("Error: main.rb not found at #{main_file} - check the path and file structure.")
      puts "ERROR: PowerLoader: main.rb not found at #{main_file}."
    end
    puts "TRACE: PowerLoader load_extension finished."
  end

  def self.reload_internal
    puts "\n--- AutoNestCut PowerLoader Reloading ---"
    cleanup
    load_extension
    puts "--- AutoNestCut PowerLoader Reload Complete ---"
  rescue => e
    warn "ERROR: AutoNestCutPowerLoader reload failed: #{e.class}: #{e.message}"
    warn e.backtrace.join("\n")
  end
end # End of module AutoNestCutPowerLoader

# --- GLOBAL HELPER FUNCTION FOR CONSOLE RELOAD ---
# This function is defined at the top-level (Object), making it universally available.
# It will always exist after `load "POWER_LOADER.rb"` is run.
def reload_autonestcut(abs_extension_dir)
  AutoNestCutPowerLoader.set_extension_path(abs_extension_dir)
  AutoNestCutPowerLoader.reload_internal
end

# Use a global variable to track if the initial hint has been printed.
$autonestcut_power_loader_hint_printed ||= false
unless $autonestcut_power_loader_hint_printed
  $autonestcut_power_loader_hint_printed = true
  puts "INFO: AutoNestCutPowerLoader loaded. To reload your extension, use the global command:"
  puts "      `reload_autonestcut(\"C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace/Extension\")`"
end
