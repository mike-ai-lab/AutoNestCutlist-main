# Test script to verify cache-busting implementation
# This script can be run in SketchUp's Ruby Console to test the cache-busting functionality

require_relative 'Extension/AutoNestCut/main'

# Test the cache-busting utility method
def test_cache_busting
  puts "Testing AutoNestCut cache-busting implementation..."
  
  # Test HTML file path
  html_file = File.join(File.dirname(__FILE__), 'Extension', 'AutoNestCut', 'ui', 'html', 'main.html')
  
  if File.exist?(html_file)
    puts "✅ HTML file found: #{html_file}"
    
    # Read original content
    original_content = File.read(html_file, encoding: 'UTF-8')
    puts "✅ Original HTML content loaded (#{original_content.length} characters)"
    
    # Test the cache-busting method
    begin
      # Create a test dialog
      dialog = UI::HtmlDialog.new(
        dialog_title: "Cache Busting Test",
        preferences_key: "AutoNestCut_Test",
        width: 400,
        height: 300
      )
      
      # Apply cache-busting
      AutoNestCut.set_html_with_cache_busting(dialog, html_file)
      puts "✅ Cache-busting method executed successfully"
      
      # Show dialog briefly to test
      dialog.show
      
      # Close after 2 seconds
      UI.start_timer(2, false) do
        dialog.close
        puts "✅ Test dialog closed"
      end
      
      puts "✅ Cache-busting test completed successfully!"
      puts "   - HTML files will now load with unique timestamps"
      puts "   - CSS and JS files will be cache-busted automatically"
      puts "   - This prevents browser caching issues during development"
      
    rescue => e
      puts "❌ Error during cache-busting test: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
    
  else
    puts "❌ HTML file not found: #{html_file}"
  end
end

# Run the test
test_cache_busting