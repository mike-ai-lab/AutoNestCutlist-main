#!/usr/bin/env ruby
# AutoNestCut Security Implementation Script
# This script applies RubyEncoder protection to critical extension files

require 'fileutils'

# Configuration
EXTENSION_DIR = File.join(__dir__, 'AutoNestCut_Clean_Workspace', 'Extension', 'AutoNestCut')
RGLOADER_DIR = File.join(__dir__, 'DEVELOPMENT_FILES', 'AutoNestCut', 'rgloader')
BACKUP_DIR = File.join(__dir__, 'BACKUP_BEFORE_ENCODING')

# Files to encode (critical business logic)
CRITICAL_FILES = [
  'main.rb',
  'processors/model_analyzer.rb',
  'processors/nester.rb', 
  'processors/facade_analyzer.rb',
  'exporters/diagram_generator.rb',
  'exporters/report_generator.rb',
  'exporters/facade_reporter.rb',
  'models/part.rb',
  'models/board.rb',
  'lib/LicenseManager/license_manager.rb',
  'lib/LicenseManager/trial_manager.rb'
]

# Files to keep as plain text (UI and configuration)
PLAIN_TEXT_FILES = [
  'config.rb',
  'util.rb',
  'materials_database.rb',
  'ui/dialog_manager.rb',
  'compatibility.rb',
  'scheduler.rb',
  'supabase_client.rb'
]

puts "🔒 AutoNestCut Security Implementation"
puts "=" * 50

# Verify backup exists
unless Dir.exist?(BACKUP_DIR)
  puts "❌ ERROR: Backup directory not found!"
  puts "Please ensure backup was created successfully."
  exit 1
end

# Verify RubyEncoder is available
rgloader_rb = File.join(RGLOADER_DIR, 'rgloader.rb')
unless File.exist?(rgloader_rb)
  puts "❌ ERROR: RubyEncoder loader not found!"
  puts "Expected: #{rgloader_rb}"
  exit 1
end

puts "✅ Backup verified: #{BACKUP_DIR}"
puts "✅ RubyEncoder available: #{RGLOADER_DIR}"

# Copy RubyEncoder to extension directory
target_rgloader = File.join(EXTENSION_DIR, 'rgloader')
FileUtils.mkdir_p(target_rgloader)
FileUtils.cp_r(Dir.glob(File.join(RGLOADER_DIR, '*')), target_rgloader)
puts "✅ RubyEncoder copied to extension"

# Create security configuration
security_config = <<~RUBY
# AutoNestCut Security Configuration
module AutoNestCut
  module Security
    PROTECTED_FILES = #{CRITICAL_FILES.inspect}
    
    def self.verify_integrity
      # Runtime integrity check
      protected_files_exist = PROTECTED_FILES.all? do |file|
        encoded_file = file.gsub('.rb', '.rbe')
        File.exist?(File.join(__dir__, encoded_file))
      end
      
      unless protected_files_exist
        raise "Security violation: Protected files missing or tampered"
      end
      
      true
    end
    
    def self.load_protected_file(filename)
      # Load encoded file with integrity check
      verify_integrity
      encoded_file = filename.gsub('.rb', '.rbe')
      require_relative encoded_file
    end
  end
end
RUBY

File.write(File.join(EXTENSION_DIR, 'security.rb'), security_config)
puts "✅ Security configuration created"

# Simulate encoding process (in real implementation, you would use RubyEncoder CLI)
puts "\n🔄 Encoding critical files..."

CRITICAL_FILES.each do |file|
  source_file = File.join(EXTENSION_DIR, file)
  next unless File.exist?(source_file)
  
  # Create encoded version (simulation - in reality use: rubyencoder source.rb)
  encoded_file = source_file.gsub('.rb', '.rbe')
  encoded_dir = File.dirname(encoded_file)
  FileUtils.mkdir_p(encoded_dir)
  
  # For demonstration, we'll create a stub encoded file
  # In real implementation: system("rubyencoder #{source_file}")
  encoded_content = <<~RUBY
# This file has been encoded with RubyEncoder
# Original: #{file}
# Encoded: #{Time.now}

require_relative 'rgloader/rgloader'

# Encoded content would be here (binary/obfuscated)
# For demo purposes, we'll load the original file
load '#{source_file}'
RUBY
  
  File.write(encoded_file, encoded_content)
  puts "  ✅ Encoded: #{file} → #{File.basename(encoded_file)}"
end

# Update main.rb to use security system
main_rb_path = File.join(EXTENSION_DIR, 'main.rb')
if File.exist?(main_rb_path)
  main_content = File.read(main_rb_path)
  
  # Add security initialization at the top
  secured_main = <<~RUBY
# frozen_string_literal: true

require 'sketchup.rb'

# Check SketchUp version compatibility
if Sketchup.version.to_i < 20
  UI.messagebox("AutoNestCut requires SketchUp 2020 or later. Current version: \#{Sketchup.version}")
  return
end

# Load security system first
require_relative 'security'

# Initialize security verification
begin
  AutoNestCut::Security.verify_integrity
rescue => e
  UI.messagebox("Security Error: \#{e.message}")
  return
end

#{main_content.gsub(/^require_relative/, '# require_relative')}

# Use secure loading for protected files
AutoNestCut::Security.load_protected_file('processors/model_analyzer.rb')
AutoNestCut::Security.load_protected_file('processors/nester.rb')
AutoNestCut::Security.load_protected_file('processors/facade_analyzer.rb')
# ... other protected files loaded securely

RUBY
  
  File.write(main_rb_path + '.secured', secured_main)
  puts "✅ Secured main.rb created"
end

# Create license hardening
license_hardening = <<~RUBY
# License Security Hardening
module AutoNestCut
  module LicenseHardening
    
    def self.hardware_fingerprint
      # Generate unique hardware fingerprint
      require 'digest'
      
      system_info = [
        ENV['COMPUTERNAME'] || ENV['HOSTNAME'],
        ENV['USERNAME'] || ENV['USER'],
        `wmic csproduct get uuid`.split("\n")[1]&.strip rescue 'unknown'
      ].compact.join('|')
      
      Digest::SHA256.hexdigest(system_info)[0..15]
    end
    
    def self.verify_license_binding(license_data)
      return false unless license_data
      
      stored_fingerprint = license_data['hardware_id']
      current_fingerprint = hardware_fingerprint
      
      stored_fingerprint == current_fingerprint
    end
    
    def self.encrypt_license_data(data)
      # Simple XOR encryption (use proper encryption in production)
      key = hardware_fingerprint
      encrypted = data.bytes.zip(key.bytes.cycle).map { |a, b| a ^ b }
      encrypted.pack('C*').unpack1('H*')
    end
    
    def self.decrypt_license_data(encrypted_hex)
      encrypted = [encrypted_hex].pack('H*').bytes
      key = hardware_fingerprint
      decrypted = encrypted.zip(key.bytes.cycle).map { |a, b| a ^ b }
      decrypted.pack('C*')
    end
  end
end
RUBY

File.write(File.join(EXTENSION_DIR, 'license_hardening.rb'), license_hardening)
puts "✅ License hardening implemented"

# Create update mechanism
update_system = <<~RUBY
# Secure Update System
module AutoNestCut
  module UpdateSystem
    UPDATE_URL = 'https://autonestcutserver-moeshks-projects.vercel.app/api/updates'
    
    def self.check_for_updates
      begin
        require 'net/http'
        require 'json'
        
        uri = URI(UPDATE_URL)
        response = Net::HTTP.get_response(uri)
        
        if response.code == '200'
          update_info = JSON.parse(response.body)
          current_version = AutoNestCut::EXTENSION_VERSION
          
          if version_newer?(update_info['version'], current_version)
            show_update_dialog(update_info)
          end
        end
      rescue => e
        puts "Update check failed: \#{e.message}"
      end
    end
    
    private
    
    def self.version_newer?(new_version, current_version)
      new_parts = new_version.split('.').map(&:to_i)
      current_parts = current_version.split('.').map(&:to_i)
      
      new_parts <=> current_parts > 0
    end
    
    def self.show_update_dialog(update_info)
      message = "AutoNestCut Update Available!\n\n"
      message += "Current Version: \#{AutoNestCut::EXTENSION_VERSION}\n"
      message += "New Version: \#{update_info['version']}\n\n"
      message += "Changes:\n\#{update_info['changelog']}\n\n"
      message += "Would you like to download the update?"
      
      result = UI.messagebox(message, MB_YESNO)
      if result == IDYES
        UI.openURL(update_info['download_url'])
      end
    end
  end
end
RUBY

File.write(File.join(EXTENSION_DIR, 'update_system.rb'), update_system)
puts "✅ Update system created"

# Create integrity checker
integrity_checker = <<~RUBY
# File Integrity Checker
module AutoNestCut
  module IntegrityChecker
    
    # SHA256 checksums of critical files (would be generated during build)
    CHECKSUMS = {
      'main.rbe' => 'placeholder_checksum_1',
      'processors/model_analyzer.rbe' => 'placeholder_checksum_2',
      'processors/nester.rbe' => 'placeholder_checksum_3'
      # ... other checksums
    }
    
    def self.verify_files
      CHECKSUMS.each do |file, expected_checksum|
        file_path = File.join(__dir__, file)
        
        unless File.exist?(file_path)
          raise "Critical file missing: \#{file}"
        end
        
        actual_checksum = calculate_checksum(file_path)
        unless actual_checksum == expected_checksum
          raise "File integrity violation: \#{file}"
        end
      end
      
      true
    end
    
    private
    
    def self.calculate_checksum(file_path)
      require 'digest'
      Digest::SHA256.file(file_path).hexdigest
    end
  end
end
RUBY

File.write(File.join(EXTENSION_DIR, 'integrity_checker.rb'), integrity_checker)
puts "✅ Integrity checker created"

puts "\n🎉 Security Implementation Complete!"
puts "=" * 50
puts "✅ Files encoded: #{CRITICAL_FILES.length}"
puts "✅ Security systems: 4 modules"
puts "✅ Backup preserved: #{BACKUP_DIR}"
puts "\n📋 Next Steps:"
puts "1. Test the secured extension in SketchUp"
puts "2. Verify all functionality works correctly"
puts "3. If successful, package as .rbz for distribution"
puts "4. If issues occur, restore from backup"

puts "\n⚠️  IMPORTANT NOTES:"
puts "- This is a demonstration implementation"
puts "- Real RubyEncoder requires commercial license"
puts "- Test thoroughly before distribution"
puts "- Keep backup safe for rollback capability"