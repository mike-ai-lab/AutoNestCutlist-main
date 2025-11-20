# Facade Materials Calculation Feature

## Overview
Add facade cladding material calculation to AutoNestCut for area-based quantities (stones, bricks, tiles) instead of cut list generation.

## What to Calculate from V121_LAYOUT Extension

### 1. Surface Analysis
- **Total facade area** (m² or ft²)
- **Net cladding area** (excluding openings like windows/doors)
- **Surface orientation** (vertical walls, horizontal surfaces)

### 2. Material Properties (from presets)
- **Stone/brick dimensions**: length × height × thickness
- **Joint specifications**: mortar gap width/height
- **Pattern type**: running bond, stack bond, etc.
- **Material name/type**: from preset color_name

### 3. Quantity Calculations
- **Pieces per m²**: based on piece size + joints
- **Total pieces needed**: area × pieces per m²
- **Waste factor**: 5-15% depending on pattern complexity
- **Joint material volume**: mortar/adhesive quantity

### 4. Cost Estimation
- **Material cost per piece** or **per m²**
- **Joint material cost** (mortar, adhesive)
- **Labor cost estimation** (optional)

## Implementation Approach

### 1. Face Detection Module
```ruby
def analyze_facade_surfaces(selection)
  surfaces = []
  selection.each do |entity|
    if entity.is_a?(Sketchup::Face)
      surfaces << {
        area: entity.area,
        normal: entity.normal,
        bounds: entity.bounds,
        material: entity.material&.name
      }
    end
  end
  surfaces
end
```

### 2. Pattern Calculator
```ruby
def calculate_cladding_quantities(surface_area, preset_data)
  piece_length = preset_data['length'].split(';').first.to_f
  piece_height = preset_data['height'].split(';').first.to_f
  joint_length = preset_data['joint_length'] || 3.0
  joint_width = preset_data['joint_width'] || 3.0
  
  effective_piece_area = (piece_length + joint_length) * (piece_height + joint_width)
  pieces_per_sqm = 1000000.0 / effective_piece_area  # Convert to pieces per m²
  
  total_pieces = (surface_area * pieces_per_sqm * 1.1).ceil  # 10% waste
  
  {
    surface_area: surface_area,
    pieces_per_sqm: pieces_per_sqm,
    total_pieces: total_pieces,
    waste_factor: 0.1
  }
end
```

### 3. Report Generation
- **Facade Summary**: total area, pattern type, material
- **Quantity Breakdown**: pieces needed, waste allowance
- **Material Specifications**: dimensions, joint sizes
- **Cost Estimation**: if pricing data available

## Integration Points

### 1. Main Menu Addition
- Add "Facade Materials" option to AutoNestCut menu
- Separate from cut list generation workflow

### 2. Selection Workflow
- Select facade surfaces (faces)
- Choose cladding preset (import from V121_LAYOUT presets)
- Generate area-based material report

### 3. Report Format
- HTML report similar to cut lists
- CSV export for quantity takeoffs
- Integration with existing export system

## File Structure
```
AutoNestCut/
├── facade/
│   ├── surface_analyzer.rb
│   ├── pattern_calculator.rb
│   ├── preset_loader.rb
│   └── facade_reporter.rb
├── ui/html/
│   └── facade_config.html
└── presets/
    └── (import from V121_LAYOUT)
```

## Benefits
- **Quantity Takeoffs**: Accurate material estimates
- **Cost Control**: Better project budgeting
- **Waste Reduction**: Proper planning reduces over-ordering
- **Integration**: Works with existing AutoNestCut workflow
- **Flexibility**: Supports various cladding types and patterns

## Next Steps
1. Create surface analyzer module
2. Import V121_LAYOUT preset system
3. Build pattern calculation engine
4. Design facade-specific UI
5. Integrate with existing report system