Strategies to Force WebDialog to Load Fresh Files (Cache Busting)


Appending a Cache-Busting Query Parameter (Most Common & Effective)
This is the most widely used and recommended method. You append a unique, dynamic query parameter to the URL of your HTML file (and ideally, to all linked CSS and JS files within that HTML) every time the dialog is opened. The browser sees this as a "new" URL and is forced to fetch the fresh resource.


How to implement:



For the main HTML file:
When you call dialog.set_html_file(path_to_html), construct the path with a unique query string. A timestamp is perfect for this.


# In your Ruby code when opening the dialog
dialog_name = "MyExtension::MyDialog" # Unique name for your dialog
html_file = File.join(__dir__, 'html', 'my_dialog.html')

# Generate a unique timestamp (or random number)
cache_buster = Time.now.to_i

# Append the cache buster to the HTML file path
# Use File.expand_path to ensure correct path formatting, then append query.
html_url = "file:///#{File.expand_path(html_file).gsub('\\', '/')}"
html_url_with_cache_buster = "#{html_url}?v=#{cache_buster}"

dialog.set_html_file(html_url_with_cache_buster)




For linked CSS/JS files within your HTML:
You need to dynamically inject the same cache buster into your <link> and <script> tags. This usually involves generating these tags dynamically with Ruby before sending the HTML, or using JavaScript to modify them on the fly (less reliable for initial load).


A more robust Ruby approach for static HTML files is to read the HTML, modify the paths, and then set_html instead of set_html_file.


Example my_dialog.html:


<!DOCTYPE html>
<html>
<head>
    <title>My Dialog</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <h1>Hello from SketchUp!</h1>
    <script src="js/script.js"></script>
</body>
</html>



Updated Ruby code to modify linked resources:


# In your Ruby code
dialog_name = "MyExtension::MyDialog"
html_file_path = File.join(__dir__, 'html', 'my_dialog.html')
cache_buster = Time.now.to_i.to_s # Use a string for the query param

# Read the HTML content
html_content = File.read(html_file_path, encoding: 'UTF-8')

# Replace relative paths with cache-busted absolute paths
# This regex looks for src="path" or href="path" attributes
html_content.gsub!(/(src|href)="(?!https?:\/\/)(.*?)"/) do |match|
  type = $1 # 'src' or 'href'
  relative_path = $2 # The actual path, e.g., 'css/style.css'

  # Construct absolute path from the directory of the HTML file
  absolute_path = File.join(File.dirname(html_file_path), relative_path)
  absolute_url = "file:///#{File.expand_path(absolute_path).gsub('\\', '/')}"

  # Append cache buster
  "#{type}=\"#{absolute_url}?v=#{cache_buster}\""
end

# Now, set the modified HTML content
dialog.set_html(html_content)





Advantages: Highly effective, browser-agnostic, works reliably with WebDialog's caching behavior.


Disadvantages: Requires Ruby-side processing of HTML if you have many linked resources, or careful management of relative paths.

Strategies to Force WebDialog to Load Fresh Files (Cache Busting)


Appending a Cache-Busting Query Parameter (Most Common & Effective)
This is the most widely used and recommended method. You append a unique, dynamic query parameter to the URL of your HTML file (and ideally, to all linked CSS and JS files within that HTML) every time the dialog is opened. The browser sees this as a "new" URL and is forced to fetch the fresh resource.


How to implement:



For the main HTML file:
When you call dialog.set_html_file(path_to_html), construct the path with a unique query string. A timestamp is perfect for this.


# In your Ruby code when opening the dialog
dialog_name = "MyExtension::MyDialog" # Unique name for your dialog
html_file = File.join(__dir__, 'html', 'my_dialog.html')

# Generate a unique timestamp (or random number)
cache_buster = Time.now.to_i

# Append the cache buster to the HTML file path
# Use File.expand_path to ensure correct path formatting, then append query.
html_url = "file:///#{File.expand_path(html_file).gsub('\\', '/')}"
html_url_with_cache_buster = "#{html_url}?v=#{cache_buster}"

dialog.set_html_file(html_url_with_cache_buster)




For linked CSS/JS files within your HTML:
You need to dynamically inject the same cache buster into your <link> and <script> tags. This usually involves generating these tags dynamically with Ruby before sending the HTML, or using JavaScript to modify them on the fly (less reliable for initial load).


A more robust Ruby approach for static HTML files is to read the HTML, modify the paths, and then set_html instead of set_html_file.


Example my_dialog.html:


<!DOCTYPE html>
<html>
<head>
    <title>My Dialog</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <h1>Hello from SketchUp!</h1>
    <script src="js/script.js"></script>
</body>
</html>



Updated Ruby code to modify linked resources:


# In your Ruby code
dialog_name = "MyExtension::MyDialog"
html_file_path = File.join(__dir__, 'html', 'my_dialog.html')
cache_buster = Time.now.to_i.to_s # Use a string for the query param

# Read the HTML content
html_content = File.read(html_file_path, encoding: 'UTF-8')

# Replace relative paths with cache-busted absolute paths
# This regex looks for src="path" or href="path" attributes
html_content.gsub!(/(src|href)="(?!https?:\/\/)(.*?)"/) do |match|
  type = $1 # 'src' or 'href'
  relative_path = $2 # The actual path, e.g., 'css/style.css'

  # Construct absolute path from the directory of the HTML file
  absolute_path = File.join(File.dirname(html_file_path), relative_path)
  absolute_url = "file:///#{File.expand_path(absolute_path).gsub('\\', '/')}"

  # Append cache buster
  "#{type}=\"#{absolute_url}?v=#{cache_buster}\""
end

# Now, set the modified HTML content
dialog.set_html(html_content)





Advantages: Highly effective, browser-agnostic, works reliably with WebDialog's caching behavior.


Disadvantages: Requires Ruby-side processing of HTML if you have many linked resources, or careful management of relative paths.

Strategies to Force WebDialog to Load Fresh Files (Cache Busting)


Appending a Cache-Busting Query Parameter (Most Common & Effective)
This is the most widely used and recommended method. You append a unique, dynamic query parameter to the URL of your HTML file (and ideally, to all linked CSS and JS files within that HTML) every time the dialog is opened. The browser sees this as a "new" URL and is forced to fetch the fresh resource.


How to implement:



For the main HTML file:
When you call dialog.set_html_file(path_to_html), construct the path with a unique query string. A timestamp is perfect for this.


# In your Ruby code when opening the dialog
dialog_name = "MyExtension::MyDialog" # Unique name for your dialog
html_file = File.join(__dir__, 'html', 'my_dialog.html')

# Generate a unique timestamp (or random number)
cache_buster = Time.now.to_i

# Append the cache buster to the HTML file path
# Use File.expand_path to ensure correct path formatting, then append query.
html_url = "file:///#{File.expand_path(html_file).gsub('\\', '/')}"
html_url_with_cache_buster = "#{html_url}?v=#{cache_buster}"

dialog.set_html_file(html_url_with_cache_buster)




For linked CSS/JS files within your HTML:
You need to dynamically inject the same cache buster into your <link> and <script> tags. This usually involves generating these tags dynamically with Ruby before sending the HTML, or using JavaScript to modify them on the fly (less reliable for initial load).


A more robust Ruby approach for static HTML files is to read the HTML, modify the paths, and then set_html instead of set_html_file.


Example my_dialog.html:


<!DOCTYPE html>
<html>
<head>
    <title>My Dialog</title>
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <h1>Hello from SketchUp!</h1>
    <script src="js/script.js"></script>
</body>
</html>



Updated Ruby code to modify linked resources:


# In your Ruby code
dialog_name = "MyExtension::MyDialog"
html_file_path = File.join(__dir__, 'html', 'my_dialog.html')
cache_buster = Time.now.to_i.to_s # Use a string for the query param

# Read the HTML content
html_content = File.read(html_file_path, encoding: 'UTF-8')

# Replace relative paths with cache-busted absolute paths
# This regex looks for src="path" or href="path" attributes
html_content.gsub!(/(src|href)="(?!https?:\/\/)(.*?)"/) do |match|
  type = $1 # 'src' or 'href'
  relative_path = $2 # The actual path, e.g., 'css/style.css'

  # Construct absolute path from the directory of the HTML file
  absolute_path = File.join(File.dirname(html_file_path), relative_path)
  absolute_url = "file:///#{File.expand_path(absolute_path).gsub('\\', '/')}"

  # Append cache buster
  "#{type}=\"#{absolute_url}?v=#{cache_buster}\""
end

# Now, set the modified HTML content
dialog.set_html(html_content)





Advantages: Highly effective, browser-agnostic, works reliably with WebDialog's caching behavior.


Disadvantages: Requires Ruby-side processing of HTML if you have many linked resources, or careful management of relative paths.
