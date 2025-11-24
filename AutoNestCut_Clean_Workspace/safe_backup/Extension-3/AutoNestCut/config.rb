require 'json'
require_relative 'compatibility' # Now explicitly requires compatibility.rb

module AutoNestCut
  module Config
    # Add a tracer to see when this module is loaded
    puts "DEBUG: AutoNestCut::Config module loading..."

    CONFIG_FILE = File.join(Compatibility.user_app_data_path, 'AutoNestCut', 'config.json')

    def self.ensure_config_folder
      folder = File.dirname(CONFIG_FILE)
      Dir.mkdir(folder) unless Dir.exist?(folder)
    end

    def self.load_global_settings
      puts "DEBUG: AutoNestCut::Config.load_global_settings called."
      ensure_config_folder
      return {} unless File.exist?(CONFIG_FILE)
      JSON.parse(File.read(CONFIG_FILE))
    rescue JSON::ParserError => e
      puts "Warning: Config file '#{CONFIG_FILE}' is corrupted. Resetting to default. Error: #{e.message}"
      # Optionally, backup the corrupted file here for debugging
      # FileUtils.cp(CONFIG_FILE, "#{CONFIG_FILE}.bak_#{Time.now.strftime('%Y%m%d%H%M%S')}") rescue nil
      return {} # Return empty settings on parse error
    rescue => e
      puts "Error loading config: #{e.message}"
      {}
    end

    def self.save_global_settings(new_settings)
      puts "DEBUG: AutoNestCut::Config.save_global_settings called with: #{new_settings}"
      ensure_config_folder
      current_settings = load_global_settings
      merged_settings = current_settings.merge(new_settings)
      File.write(CONFIG_FILE, merged_settings.to_json)
      @cached_settings = merged_settings # Update cache
    rescue => e
      puts "Error saving config: #{e.message}"
    end

    def self.get_cached_settings
      puts "DEBUG: AutoNestCut::Config.get_cached_settings called."
      # Use `defined?(@cached_settings)` to prevent re-loading on every call if not explicitly nilled
      @cached_settings ||= load_global_settings
      puts "DEBUG: Cached settings: #{@cached_settings}"
      @cached_settings
    end
  end
  puts "DEBUG: AutoNestCut::Config module loaded successfully."
end
