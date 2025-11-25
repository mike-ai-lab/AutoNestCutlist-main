# Test script for AutoNestCut Progress System
# Run this in SketchUp Ruby Console to test the progress dialog

# Load the extension if not already loaded
unless defined?(AutoNestCut)
  load 'c:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace/Extension/AutoNestCut/main.rb'
end

# Test the progress dialog
def test_progress_dialog
  puts "Testing AutoNestCut Progress Dialog..."
  
  # Create and show progress dialog
  progress = AutoNestCut::ProgressDialog.new
  progress.show("Testing Progress System", 100)
  
  # Simulate processing steps
  steps = [
    "Initializing components...",
    "Analyzing geometry...", 
    "Building hierarchy tree...",
    "Extracting sheet goods...",
    "Optimizing layouts...",
    "Generating reports...",
    "Finalizing results..."
  ]
  
  steps.each_with_index do |step, index|
    percentage = ((index + 1).to_f / steps.length * 100).round(1)
    progress.update_progress(index + 1, steps.length, step, percentage)
    
    # Simulate work
    sleep(1.5)
    
    # Check if cancelled
    if progress.cancelled?
      puts "Progress cancelled by user"
      break
    end
  end
  
  # Close dialog
  sleep(1)
  progress.close
  puts "Progress dialog test completed!"
end

# Test async processor detection
def test_async_detection
  puts "Testing Async Processor Detection..."
  
  model = Sketchup.active_model
  selection = model.selection
  
  if selection.empty?
    puts "Please select some components first"
    return
  end
  
  processor = AutoNestCut::AsyncProcessor.new
  should_use_async = processor.should_use_async?(selection)
  
  puts "Selection count: #{selection.length}"
  puts "Should use async: #{should_use_async}"
  puts "Threshold: #{AutoNestCut::AsyncProcessor::ASYNC_THRESHOLD}"
end

# Run tests
puts "=" * 50
puts "AutoNestCut Progress System Test"
puts "=" * 50

# Test 1: Progress Dialog
test_progress_dialog

# Test 2: Async Detection
test_async_detection

puts "All tests completed!"