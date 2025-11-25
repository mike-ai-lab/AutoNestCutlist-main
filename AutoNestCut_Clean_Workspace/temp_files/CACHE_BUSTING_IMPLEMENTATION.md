# Cache-Busting Implementation for AutoNestCut

## Overview

This implementation adds cache-busting functionality to the AutoNestCut SketchUp extension to prevent browser caching issues with HTML dialogs and their linked resources (CSS, JS files).

## Problem Solved

SketchUp's WebDialog and HtmlDialog components use an embedded browser that aggressively caches HTML, CSS, and JavaScript files. During development, this causes:
- Changes to HTML/CSS/JS files not appearing in dialogs
- Need to restart SketchUp to see updates
- Inconsistent behavior between development and production

## Solution

### Cache-Busting Strategy

The implementation uses the **query parameter cache-busting** method, which:
1. Appends a unique timestamp to all file URLs (`?v=1234567890`)
2. Forces the browser to treat each load as a new resource
3. Works reliably across all browsers and SketchUp versions

### Implementation Details

#### 1. Shared Utility Method

Added to `main.rb`:
```ruby
def self.set_html_with_cache_busting(dialog, html_file_path)
  cache_buster = Time.now.to_i.to_s
  
  # Read the HTML content
  html_content = File.read(html_file_path, encoding: 'UTF-8')
  
  # Replace relative paths with cache-busted absolute paths
  html_content.gsub!(/(src|href)="(?!https?:\/\/)([^"]*?)"/) do |match|
    type = $1 # 'src' or 'href'
    relative_path = $2 # The actual path
    
    # Skip if it's already an absolute URL or data URL
    next match if relative_path.start_with?('http', 'data:', '//')
    
    # Construct absolute path from the directory of the HTML file
    absolute_path = File.join(File.dirname(html_file_path), relative_path)
    absolute_url = "file:///#{File.expand_path(absolute_path).gsub('\\', '/')}"
    
    # Append cache buster
    "#{type}=\"#{absolute_url}?v=#{cache_buster}\""
  end
  
  # Set the modified HTML content
  dialog.set_html(html_content)
end
```

#### 2. Updated Dialog Methods

The following methods now use cache-busting:

**main.rb:**
- `show_documentation` - Documentation dialog
- `show_scheduler` - Scheduled exports dialog  
- `show_facade_calculator` - Facade materials calculator

**ui/dialog_manager.rb:**
- `show_config_dialog` - Main configuration dialog

#### 3. Files Modified

1. **main.rb**
   - Added shared `set_html_with_cache_busting` method
   - Updated `show_documentation`, `show_scheduler`, `show_facade_calculator`

2. **ui/dialog_manager.rb**
   - Updated `show_config_dialog` to use shared cache-busting method
   - Removed duplicate cache-busting implementation

## How It Works

### Before Cache-Busting
```html
<link rel="stylesheet" href="style.css">
<script src="app.js"></script>
```

### After Cache-Busting
```html
<link rel="stylesheet" href="file:///C:/path/to/style.css?v=1703123456">
<script src="file:///C:/path/to/app.js?v=1703123456"></script>
```

### Process Flow

1. Dialog creation starts
2. `set_html_with_cache_busting` is called with dialog and HTML file path
3. HTML content is read from file
4. Regex finds all `src` and `href` attributes with relative paths
5. Each relative path is converted to absolute path with timestamp
6. Modified HTML is set on dialog using `set_html()`
7. Browser loads all resources as "new" due to unique timestamps

## Benefits

✅ **Immediate Updates**: Changes to HTML/CSS/JS appear instantly  
✅ **Development Friendly**: No need to restart SketchUp during development  
✅ **Cross-Platform**: Works on Windows, Mac, and Linux  
✅ **Browser Agnostic**: Compatible with all embedded browser versions  
✅ **Minimal Overhead**: Only processes HTML once per dialog load  
✅ **Selective**: Only affects relative paths, preserves external URLs  

## Testing

Run the test script to verify implementation:
```ruby
load 'cache_busting_test.rb'
```

## Files Affected

### HTML Files with Cache-Busting
- `ui/html/main.html` - Main configuration dialog
- `ui/html/documentation.html` - Documentation dialog
- `ui/html/scheduler.html` - Scheduler dialog
- `ui/html/facade_config.html` - Facade calculator dialog

### Linked Resources (Auto Cache-Busted)
- `ui/html/style.css`
- `ui/html/diagrams_style.css`
- `ui/html/resizer_fix.css`
- `ui/html/app.js`
- `ui/html/diagrams_report.js`
- `ui/html/table_customization.js`
- `ui/html/resizer_fix.js`
- `ui/html/languages.js`
- `ui/html/assembly_viewer.js`
- `ui/html/FileSaver.min.js`
- `ui/html/html2pdf.bundle.min.js`
- `ui/html/font-awesome.min.css`
- `ui/html/js/OrbitControls.js`
- All image files in `ui/html/images/`

## Notes

- The `progress_dialog.rb` and `license_dialog.rb` use inline HTML generation, so they don't need cache-busting
- External URLs (http/https) and data URLs are preserved unchanged
- The implementation is minimal and focused - only adds what's necessary
- Timestamps ensure uniqueness across multiple dialog opens
- File paths are properly escaped for Windows compatibility

## Future Enhancements

If needed, the implementation could be extended to:
- Add cache-busting to dynamically loaded content
- Implement more sophisticated cache invalidation strategies
- Add debug logging for cache-busting operations
- Support for additional file types or URL patterns