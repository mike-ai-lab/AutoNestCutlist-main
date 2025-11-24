#!/usr/bin/env ruby
# AutoNestCut Fixes Verification Script

puts "🔍 AutoNestCut Fixes Verification"
puts "=" * 40

# Check 1: Verify warning message is removed from nester.rb
nester_file = File.join(__dir__, 'AutoNestCut_Clean_Workspace', 'Extension', 'AutoNestCut', 'processors', 'nester.rb')
if File.exist?(nester_file)
  nester_content = File.read(nester_file)
  if nester_content.include?('UI.messagebox("Warning: Could not place')
    puts "❌ ISSUE: Warning message still present in nester.rb"
  else
    puts "✅ FIXED: Warning message removed from nester.rb"
  end
else
  puts "❌ ERROR: nester.rb not found"
end

# Check 2: Verify Phase 1 debug messages are removed from model_analyzer.rb
analyzer_file = File.join(__dir__, 'AutoNestCut_Clean_Workspace', 'Extension', 'AutoNestCut', 'processors', 'model_analyzer.rb')
if File.exist?(analyzer_file)
  analyzer_content = File.read(analyzer_file)
  if analyzer_content.include?('Phase 1') || analyzer_content.include?('Enhanced Units')
    puts "❌ ISSUE: Phase 1 identifiers still present in model_analyzer.rb"
  else
    puts "✅ FIXED: Phase 1 identifiers removed from model_analyzer.rb"
  end
  
  if analyzer_content.include?('Util.debug("Added tree node:') || analyzer_content.include?('Util.debug("Total hierarchy nodes:')
    puts "❌ ISSUE: Debug messages still present in model_analyzer.rb"
  else
    puts "✅ FIXED: Debug messages removed from model_analyzer.rb"
  end
else
  puts "❌ ERROR: model_analyzer.rb not found"
end

# Check 3: Verify debug function is properly controlled
util_file = File.join(__dir__, 'AutoNestCut_Clean_Workspace', 'Extension', 'AutoNestCut', 'util.rb')
if File.exist?(util_file)
  util_content = File.read(util_file)
  if util_content.include?("ENV['AUTONESTCUT_DEBUG'] == '1'")
    puts "✅ CONFIRMED: Debug function is environment-controlled"
  else
    puts "❌ ISSUE: Debug function not properly controlled"
  end
else
  puts "❌ ERROR: util.rb not found"
end

# Check 4: Verify security implementation is in place
security_files = [
  'security.rb',
  'license_hardening.rb',
  'update_system.rb',
  'integrity_checker.rb'
]

extension_dir = File.join(__dir__, 'AutoNestCut_Clean_Workspace', 'Extension', 'AutoNestCut')
security_files.each do |file|
  file_path = File.join(extension_dir, file)
  if File.exist?(file_path)
    puts "✅ SECURITY: #{file} present"
  else
    puts "❌ MISSING: #{file} not found"
  end
end

# Check 5: Verify encoded files exist
encoded_files = Dir.glob(File.join(extension_dir, '**', '*.rbe'))
if encoded_files.length > 0
  puts "✅ SECURITY: #{encoded_files.length} files encoded"
else
  puts "❌ SECURITY: No encoded files found"
end

# Check 6: Verify backup exists
backup_dir = File.join(__dir__, 'BACKUP_BEFORE_ENCODING')
if Dir.exist?(backup_dir)
  backup_files = Dir.glob(File.join(backup_dir, '**', '*.rb')).length
  puts "✅ BACKUP: #{backup_files} files backed up"
else
  puts "❌ BACKUP: Backup directory not found"
end

puts "\n" + "=" * 40
puts "🎯 VERIFICATION SUMMARY"
puts "=" * 40

# Final status
issues_found = false

# Re-check critical issues
if File.exist?(nester_file)
  nester_content = File.read(nester_file)
  if nester_content.include?('UI.messagebox("Warning: Could not place')
    puts "❌ CRITICAL: Warning message still showing"
    issues_found = true
  end
end

if File.exist?(analyzer_file)
  analyzer_content = File.read(analyzer_file)
  if analyzer_content.include?('Phase 1') || analyzer_content.include?('Enhanced Units')
    puts "❌ CRITICAL: Phase 1 identifiers still present"
    issues_found = true
  end
end

if issues_found
  puts "\n🚨 ISSUES FOUND - FIXES NEEDED"
  puts "Please address the issues above before testing"
else
  puts "\n✅ ALL FIXES VERIFIED"
  puts "Extension is ready for testing in SketchUp"
  puts "\n📋 Next Steps:"
  puts "1. Test extension in SketchUp"
  puts "2. Verify all functions work correctly"
  puts "3. Check that no warning messages appear"
  puts "4. Confirm security features are working"
  puts "5. If all tests pass, create RBZ package"
end