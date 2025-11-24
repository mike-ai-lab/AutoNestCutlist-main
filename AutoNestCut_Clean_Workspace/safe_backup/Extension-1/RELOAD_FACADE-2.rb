# C:\Users\Administrator\Desktop\AUTOMATION\cutlist\AutoNestCut\AutoNestCut_Clean_Workspace\Extension\RELOAD_FACADE.rb

# This script provides explicit Unload and Reload functionality for the AutoNestCut extension
# for development purposes. It aims to clean up UI elements and Ruby's loaded features
# to simulate an unload and ensure fresh code execution upon reload.

module AutoNestCutDevTools
  # --- Configuration ---
  # IMPORTANT: Customize these constants to match your AutoNestCut extension details.

  # Full Path to the root directory of your AutoNestCut extension.
  # This is the folder containing your main .rb file (e.g., 'main.rb') and other assets.
  EXTENSION_ROOT_PATH = 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace/Extension/AutoNestCut'.freeze

  # The name of the main Ruby file that starts your extension.
  # Based on your 'tree /f' output, this is 'main.rb'.
  MAIN_EXTENSION_RB_FILE_NAME = 'main.rb'.freeze

  # The exact name of the toolbar created by your AutoNestCut extension.
  # You MUST find this name in your extension's code (e.g., UI::Toolbar.new("Your Toolbar Name")).
  # If your extension creates multiple toolbars, list them here to ensure they are all removed.
  AUTO_NEST_CUT_TOOLBAR_NAMES = ['AutoNestCut', 'AnotherAutoNestCutToolbar'].freeze # <<--- CUSTOMIZE THIS ARRAY

  # An array of exact names of top-level menu items created by your AutoNestCut extension.
  # These are typically found under SketchUp's 'Extensions' menu.
  # Example: If your menu looks like Extensions -> AutoNestCut -> Item 1, Item 2
  # then you'd list ['AutoNestCut']. If it creates multiple root menus, list them all.
  AUTO_NEST_CUT_TOP_LEVEL_MENU_ITEMS = ['AutoNestCut'].freeze # <<--- CUSTOMIZE THIS ARRAY

  # If your extension uses a distinct top-level Ruby module (e.g., `module AutoNestCut`, or `module MyCompany::AutoNestCut`),
  # provide its full name as a string here. This allows the script to try and remove its constants.
  # For `module AutoNestCut`, use "AutoNestCut".
  # For `module MyCompany::AutoNestCut`, use "MyCompany".
  # If your extension defines classes/modules directly under `Sketchup` or globally without a distinct top-level module,
  # setting this might not be fully effective, or you might need to list individual global class names.
  # Leave as `nil` if you're unsure or your extension doesn't use a single top-level module.
  AUTO_NEST_CUT_TOP_LEVEL_MODULE_NAME = "AutoNestCut".freeze # <<--- CUSTOMIZE THIS (if applicable)

  # Path for developer toolbar icons (relative to this script's directory)
  DEV_TOOLBAR_RESOURCES_PATH = File.join(__dir__, "resources").freeze
  # --- End Configuration ---

  # Utility method to normalize paths to use forward slashes for consistency
  def self.normalize_path(path)
    File.expand_path(path).gsub('\\', '/')
  end

  # --- UNLOAD Logic ---
  def self.perform_unload
    puts "\n--- AutoNestCut Unload Process Started ---"
    normalized_root_path = normalize_path(EXTENSION_ROOT_PATH)
    main_extension_file = File.join(normalized_root_path, MAIN_EXTENSION_RB_FILE_NAME)

    # Step 1: Attempt to remove UI elements (Toolbars and Menu items)
    puts "Attempting to remove AutoNestCut UI elements..."

    # Remove Toolbars
    AUTO_NEST_CUT_TOOLBAR_NAMES.each do |toolbar_name|
      toolbar = Sketchup::Toolbar.all.find { |tb| tb.name == toolbar_name }
      if toolbar
        toolbar.close
        Sketchup::Toolbar.all.delete(toolbar)
        puts "  - Toolbar '#{toolbar_name}' removed."
      else
        puts "  - Toolbar '#{toolbar_name}' not found or already removed."
      end
    end

    # Remove Top-Level Menu Items
    # This involves rebuilding the parent 'Extensions' menu to truly remove an item.
    # The SketchUp API does not provide a direct `remove_menu_item` by name.
    # For dev purposes, we'll try to explicitly remove by iterating, but this is less robust.
    # A more common approach is that `require` (on reload) will simply redefine the menu items.
    # To truly remove, we'd have to identify the Sketchup::Menu objects and rebuild them.
    # For a top-level menu created by ExtensionManager, setting `unregistered_extension` below
    # should hide it from the Extensions menu list.
    if !AUTO_NEST_CUT_TOP_LEVEL_MENU_ITEMS.empty?
      puts "  - Note: Direct removal of individual menu items '#{AUTO_NEST_CUT_TOP_LEVEL_MENU_ITEMS.join(', ')}' from the SketchUp 'Extensions' menu is not robustly supported by API without rebuilding the parent menu structure. We rely on the extension's load/unload behavior or a restart."
    end


    # Step 2: Clear `$LOADED_FEATURES` cache for the specific extension
    puts "Clearing Ruby's $LOADED_FEATURES cache for '#{File.basename(EXTENSION_ROOT_PATH)}'..."
    features_removed_count = 0
    original_loaded_features_size = $LOADED_FEATURES.size

    # `reject!` modifies the array in place, removing elements for which the block returns true.
    $LOADED_FEATURES.reject! do |path|
      # Check if the loaded feature path starts with the normalized root path of our extension.
      if normalize_path(path).start_with?(normalized_root_path)
        # puts "  - Removed from $LOADED_FEATURES: #{path.gsub('/', '\\')}" # Commented for less verbose output
        features_removed_count += 1
        true # Remove this feature
      else
        false # Keep this feature
      end
    end

    puts "  - Cleared #{features_removed_count} entries from $LOADED_FEATURES (total before: #{original_loaded_features_size}, total after: #{$LOADED_FEATURES.size})."

    # Step 3: Attempt to remove top-level module constants
    # This tries to remove the extension's main module from the global namespace.
    # This can help prevent old code references from lingering.
    if AUTO_NEST_CUT_TOP_LEVEL_MODULE_NAME && Object.const_defined?(AUTO_NEST_CUT_TOP_LEVEL_MODULE_NAME)
      begin
        Object.send(:remove_const, AUTO_NEST_CUT_TOP_LEVEL_MODULE_NAME)
        puts "  - Removed top-level module '#{AUTO_NEST_CUT_TOP_LEVEL_MODULE_NAME}' constant from ObjectSpace."
      rescue NameError => e
        puts "  - Warning: Could not remove module constant '#{AUTO_NEST_CUT_TOP_LEVEL_MODULE_NAME}': #{e.message}. It might be referenced elsewhere or not a top-level constant."
      end
    else
      puts "  - No specific top-level module '#{AUTO_NEST_CUT_TOP_LEVEL_MODULE_NAME}' found or specified to remove."
    end

    # Step 4: Mark extension as unloaded with SketchUp's Extension Manager
    # This informs SketchUp's internal tracking that the extension is no longer active.
    # This typically hides the extension from the Extensions menu list if it was registered with SketchupExtension.
    Sketchup::Extensions.all.each do |ext|
      # Assuming the extension name in Sketchup::Extensions contains 'AutoNestCut'
      if ext.name.include?("AutoNestCut")
        ext.unregistered_extension # This method marks it as unloaded.
        puts "  - Marked extension '#{ext.name}' as unregistered/unloaded in Sketchup::Extensions."
        break # Assuming only one extension matching 'AutoNestCut'
      end
    end

    # IMPORTANT: Inform the user about the limitations
    puts "\n--- AutoNestCut Unload Process Completed ---"
    puts "NOTE: Unloading for development purposes is a 'best effort' to clear caches and UI."
    puts "It removes toolbars, clears Ruby's `$LOADED_FEATURES`, and attempts to remove main module constants."
    puts "You should now observe the extension's UI (toolbars, menus) to be absent or non-functional."
    puts "However, fully deactivating all background processes, observers, or objects created by an extension"
    puts "without a SketchUp restart is complex and requires explicit 'teardown' logic within the extension itself."
    puts "If you observe residual behavior or unexpected errors, a SketchUp restart remains the most definitive cleanup method."
    puts "Please try to use the extension now to verify its unloaded state."
  rescue StandardError => e
    puts "\nERROR during AutoNestCut unload process:"
    puts "  Type: #{e.class}"
    puts "  Message: #{e.message}"
    puts "  Backtrace:\n#{e.backtrace.join("\n  ")}"
    puts "--- AutoNestCut Unload Process Aborted ---"
  end

  # --- RELOAD Logic ---
  def self.perform_reload
    puts "\n--- AutoNestCut Reload Process Started ---"
    normalized_root_path = normalize_path(EXTENSION_ROOT_PATH)
    main_extension_file = File.join(normalized_root_path, MAIN_EXTENSION_RB_FILE_NAME)

    # Before reloading, it's crucial to try and unload any previous instance.
    # This also handles clearing `$LOADED_FEATURES`.
    puts "Performing preliminary unload before reload..."
    perform_unload # Call the unload logic to clean up previous state.

    # Verify the main extension file exists before proceeding with reload
    unless File.exist?(main_extension_file)
      puts "ERROR: Main extension file '#{main_extension_file.gsub('/', '\\')}' not found for reload."
      puts "Please ensure 'EXTENSION_ROOT_PATH' and 'MAIN_EXTENSION_RB_FILE_NAME' are correct in RELOAD_FACADE.rb."
      puts "--- AutoNestCut Reload Process Aborted ---"
      return
    end

    puts "\nAttempting to reload the main extension file: #{main_extension_file.gsub('/', '\\')}..."
    begin
      # `require` is the standard way to load extensions. By clearing `$LOADED_FEATURES` and
      # module constants beforehand, `require` will re-execute the extension's main file
      # and its dependencies as if it were loading for the first time, ensuring fresh code.
      require main_extension_file

      puts "\nSuccessfully reloaded '#{File.basename(main_extension_file)}'."
      puts "Your AutoNestCut extension should now be running the latest code version."
      puts "Please check for its toolbar and menu items to ensure they are present and functional."

    rescue LoadError => e
      puts "\nERROR: Failed to load '#{main_extension_file.gsub('/', '\\')}'."
      puts "  Message: #{e.message}"
      puts "  Ensure all required files exist, paths are correct, and there are no syntax errors."
    rescue StandardError => e
      puts "\nAn unexpected error occurred during extension reload:"
      puts "  Type: #{e.class}"
      puts "  Message: #{e.message}"
      puts "  Backtrace:\n#{e.backtrace.join("\n  ")}"
    ensure
      puts "\n--- AutoNestCut Reload Process Finished ---"
    end
  end

  # --- UI for Developer Tools ---
  def self.create_dev_toolbar
    unless @dev_toolbar
      puts "\nCreating 'AutoNestCut Dev Tools' toolbar..."
      @dev_toolbar = UI::Toolbar.new("AutoNestCut Dev Tools")

      cmd_unload = UI::Command.new("Unload AutoNestCut") { self.perform_unload }
      cmd_unload.tooltip = "Unload AutoNestCut Extension for development cleanup."
      cmd_unload.status_bar_text = "Removes AutoNestCut UI, clears Ruby cache, and module constants."
      cmd_unload.small_icon = File.join(DEV_TOOLBAR_RESOURCES_PATH, "unload_small.png")
      cmd_unload.large_icon = File.join(DEV_TOOLBAR_RESOURCES_PATH, "unload_large.png")
      @dev_toolbar.add_item(cmd_unload)

      cmd_reload = UI::Command.new("Reload AutoNestCut") { self.perform_reload }
      cmd_reload.tooltip = "Reload AutoNestCut Extension with latest code changes."
      cmd_reload.status_bar_text = "Performs unload then reloads AutoNestCut extension from files."
      cmd_reload.small_icon = File.join(DEV_TOOLBAR_RESOURCES_PATH, "reload_small.png")
      cmd_reload.large_icon = File.join(DEV_TOOLBAR_RESOURCES_PATH, "reload_large.png")
      @dev_toolbar.add_item(cmd_reload)

      @dev_toolbar.show
      puts "  - 'AutoNestCut Dev Tools' toolbar created with Unload and Reload buttons."
    else
      puts "  - 'AutoNestCut Dev Tools' toolbar already exists, showing it."
      @dev_toolbar.show # Ensure it's visible if already created
    end
  rescue StandardError => e
    puts "\nERROR creating developer toolbar:"
    puts "  Type: #{e.class}"
    puts "  Message: #{e.message}"
    puts "  Backtrace:\n#{e.backtrace.join("\n  ")}"
  end
end

# --- Initialization Logic ---
# Ensure the developer toolbar is created when this RELOAD_FACADE.rb file is loaded.
AutoNestCutDevTools.create_dev_toolbar

# Initial check for AutoNestCut extension load status.
# If AutoNestCut is not detected as loaded, this will perform an initial reload.
# This makes sure the dev tools are ready and the extension is active when SketchUp starts.
unless $LOADED_FEATURES.any? { |path| AutoNestCutDevTools.normalize_path(path).start_with?(AutoNestCutDevTools.normalize_path(AutoNestCutDevTools::EXTENSION_ROOT_PATH)) }
  puts "\n--- AutoNestCut Initial Load Check ---"
  puts "AutoNestCut not detected as loaded through its files. Performing an initial reload via DevTools."
  AutoNestCutDevTools.perform_reload
else
  puts "\n--- AutoNestCut Initial Load Check ---"
  puts "AutoNestCut detected as already loaded. Use the 'AutoNestCut Dev Tools' toolbar buttons to Unload/Reload."
end
