# Reload AutoNestCut with facade feature
begin
  # Remove existing constants
  Object.send(:remove_const, :AutoNestCut) if defined?(AutoNestCut)
  
  # Clear loaded features
  $LOADED_FEATURES.delete_if { |f| f.include?('AutoNestCut') }
  
  # Load main file
  load File.join(__dir__, 'AutoNestCut', 'main.rb')
  
  puts "✅ AutoNestCut reloaded with facade materials feature"
  puts "📋 Menu: Extensions > Auto Nest Cut > Facade Materials Calculator"
rescue => e
  puts "❌ Reload error: #{e.message}"
  puts e.backtrace.first(3)
end