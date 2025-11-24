# TEST SCRIPT - Run this in SketchUp Ruby Console to create test components
# This will create components with different edge banding and grain settings

model = Sketchup.active_model
entities = model.entities

# Clear selection first
model.selection.clear

# Create test components with different edge banding
test_components = []

# Component 1: All 4 edges
comp1 = entities.add_group
comp1.entities.add_face([0,0,0], [600,0,0], [600,300,0], [0,300,0])
comp1.entities.add_face([0,0,0], [0,0,18], [600,0,18], [600,0,0])
comp1.entities.add_face([600,0,0], [600,0,18], [600,300,18], [600,300,0])
comp1.entities.add_face([600,300,0], [600,300,18], [0,300,18], [0,300,0])
comp1.entities.add_face([0,300,0], [0,300,18], [0,0,18], [0,0,0])
comp1.entities.add_face([0,0,18], [0,300,18], [600,300,18], [600,0,18])
comp1.name = "Cabinet_Door_All_Edges"
comp1.set_attribute('AutoNestCut', 'EdgeBanding', 'All 4 edges 1mm PVC')
comp1.set_attribute('AutoNestCut', 'GrainDirection', 'L')
test_components << comp1

# Component 2: 2 long edges only
comp2 = entities.add_group
comp2.entities.add_face([700,0,0], [1500,0,0], [1500,200,0], [700,200,0])
comp2.entities.add_face([700,0,0], [700,0,18], [1500,0,18], [1500,0,0])
comp2.entities.add_face([1500,0,0], [1500,0,18], [1500,200,18], [1500,200,0])
comp2.entities.add_face([1500,200,0], [1500,200,18], [700,200,18], [700,200,0])
comp2.entities.add_face([700,200,0], [700,200,18], [700,0,18], [700,0,0])
comp2.entities.add_face([700,0,18], [700,200,18], [1500,200,18], [1500,0,18])
comp2.name = "Shelf_Long_Edges"
comp2.set_attribute('AutoNestCut', 'EdgeBanding', '2 long edges 0.5mm ABS')
comp2.set_attribute('AutoNestCut', 'GrainDirection', 'W')
test_components << comp2

# Component 3: No edge banding
comp3 = entities.add_group
comp3.entities.add_face([0,400,0], [400,400,0], [400,600,0], [0,600,0])
comp3.entities.add_face([0,400,0], [0,400,18], [400,400,18], [400,400,0])
comp3.entities.add_face([400,400,0], [400,400,18], [400,600,18], [400,600,0])
comp3.entities.add_face([400,600,0], [400,600,18], [0,600,18], [0,600,0])
comp3.entities.add_face([0,600,0], [0,600,18], [0,400,18], [0,400,0])
comp3.entities.add_face([0,400,18], [0,600,18], [400,600,18], [400,400,18])
comp3.name = "Hidden_Panel"
comp3.set_attribute('AutoNestCut', 'EdgeBanding', 'None')
comp3.set_attribute('AutoNestCut', 'GrainDirection', 'Any')
test_components << comp3

# Select all test components
test_components.each { |comp| model.selection.add(comp) }

puts "✅ Created 3 test components with different edge banding:"
puts "1. Cabinet_Door_All_Edges - All 4 edges 1mm PVC, Grain: L"
puts "2. Shelf_Long_Edges - 2 long edges 0.5mm ABS, Grain: W" 
puts "3. Hidden_Panel - None, Grain: Any"
puts ""
puts "Now run AutoNestCut to see the different edge banding and grain values!"