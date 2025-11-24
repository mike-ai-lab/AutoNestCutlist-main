# Save this file as 'autonestcut_stylesheet_updater.rb' in your AutoNestCut extension directory (e.g., in an 'Utils' subfolder).
# Ensure the final 'CSS_BLOCK' line (around line 105) is flush with the left margin (no leading whitespace).

# Save this file as 'autonestcut_stylesheet_updater.rb' in your AutoNestCut extension directory (e.g., in an 'Utils' subfolder).
# Ensure the final 'CSS_BLOCK' line (around line 105) is flush with the left margin (no leading whitespace).

module AutoNestCut
  module Utils
    # This method updates the style.css file with specific layout and alignment fixes for tables.
    # It ensures the Cost Breakdown table has proper width and all table cells are aligned correctly.
    def self.update_stylesheet
      # 1. Define the path to style.css
      # This assumes the script is in 'AutoNestCut/Utils/' and style.css is in 'AutoNestCut/html/'.
      # Adjust `File.dirname` if your 'html' folder is in a different relative location.
      extension_root = File.dirname(File.dirname(__FILE__)) # Go up two levels from current script location
      css_file_path = File.join(extension_root, 'html', 'style.css') # Assuming 'html' is directly under the extension root

      unless File.exist?(css_file_path)
        UI.messagebox("Error: style.css not found at:\n#{css_file_path}\nCannot apply updates. Please ensure the file exists.", MB_OK, "AutoNestCut Stylesheet Update")
        return false
      end

      # Read the original content of the stylesheet
      original_content = File.read(css_file_path)
      new_content = original_content.dup # Work on a duplicate

      # Flag to track if any changes were made
      changes_made = false

      # --- Modification 1: Comment out 'text-align: left;' from general 'th, td' block ---
      # This regex attempts to find the 'th, td { ... }' block and then modify the 'text-align'
      # property specifically within it.
      # Using a non-greedy match (.*?) to ensure it doesn't span across multiple CSS blocks.
      # The `m` flag allows `.` to match newlines, `^` and `$` match start/end of line.
      th_td_block_regex = /(th,\s*td\s*\{\s*)(.*?)(^\s*text-align:\s*left;\s*$)(.*?)\}/m

      if new_content =~ th_td_block_regex
        # Replace the matched 'text-align: left;' line with a commented-out version
        new_content.gsub!(th_td_block_regex) do |match|
          "#{Regexp.last_match(1)}#{Regexp.last_match(2)}/* #{Regexp.last_match(3).strip} */#{Regexp.last_match(4)}"
        end
        UI.messagebox("Successfully commented out 'text-align: left;' from general 'th, td' block.", MB_OK, "AutoNestCut Stylesheet Update")
        changes_made = true
      else
        UI.messagebox("Warning: 'text-align: left;' (or its containing 'th, td' block) not found in style.css. Skipping this modification.", MB_OK, "AutoNestCut Stylesheet Update")
      end

      # --- Modification 2: Replace the entire '#costBreakdownContainer' block ---
      # This block defines the new, corrected CSS for the Cost Breakdown table.
      # IMPORTANT: The `CSS_BLOCK` identifier below MUST be flush with the left margin
      # (no leading spaces) to correctly terminate the heredoc string.
      new_cost_breakdown_css = <<-CSS_BLOCK
/* Override for Cost Breakdown Table: Width and Alignment */
/* This section targets the table within the specific #costBreakdownContainer.
   It sets explicit column widths and ensures correct text alignment as per the desired layout. */

/* Ensure fixed table layout for the cost breakdown table, with highest specificity */
#costBreakdownContainer .table-wrapper table {
    width: 100% !important; /* Ensures table fills its parent (the .table-wrapper) */
    table-layout: fixed !important; /* Force fixed layout for predictable column widths */
    min-width: unset !important; /* Ensure no conflicting min-width is forcing it wider */
}

/* General cell padding, min-width removal, and text wrapping for cost breakdown cells */
#costBreakdownContainer .table-wrapper table th,
#costBreakdownContainer .table-wrapper table td {
    padding: 8px 12px !important; /* Maintain original padding */
    min-width: auto !important; /* Ensure no min-width forces individual cells wide */
    white-space: normal !important; /* Ensure text can wrap within cells */
    word-wrap: break-word !important; /* Ensures long words break to prevent overflow */
}

/* Define explicit widths and text alignment for each column in the Cost Breakdown table */
/* (Adjust percentages if your content significantly changes or you have more/fewer columns) */
#costBreakdownContainer .table-wrapper table th:first-child,
#costBreakdownContainer .table-wrapper table td:first-child {
    width: 40% !important; /* Material Name: Give more space for descriptions */
    text-align: left !important;
}

#costBreakdownContainer .table-wrapper table th:nth-child(2),
#costBreakdownContainer .table-wrapper table td:nth-child(2) {
    width: 15% !important; /* Parts Count: Generally smaller numbers */
    text-align: right !important;
}

#costBreakdownContainer .table-wrapper table th:nth-child(3),
#costBreakdownContainer .table-wrapper table td:nth-child(3) {
    width: 25% !important; /* Total Cost: Monetary values */
    text-align: right !important;
}

#costBreakdownContainer .table-wrapper table th:nth-child(4),
#costBreakdownContainer .table-wrapper table td:nth-child(4) {
    width: 20% !important; /* Percentage: Small values */
    text-align: right !important;
}
/* Total for columns: 40% + 15% + 25% + 20% = 100% */
CSS_BLOCK
      # Regex to find the *old* cost breakdown block.
      # It looks for the specific comment `/* Override for cost breakdown table - REVISION */`
      # and captures everything until the next `th { position: sticky;` rule or the end of the file.
      # Options: 'm' for multiline, 'x' for extended (allows comments and whitespace within the regex pattern itself).
      old_cost_breakdown_regex = %r{
        /\*\s*Override\s*for\s*cost\s*breakdown\s*table\s*-\s*REVISION\s*\*/ # Start comment marker within regex
        .*?                                                             # Non-greedy match for anything (the old CSS rules)
        (?=\s*th\s*\{\s*position:\s*sticky;|\Z)                         # Lookahead: ends before 'th { position: sticky;' or end of file
      }mx # Placed on its own line for clarity and to prevent parsing issues.

      if new_content =~ old_cost_breakdown_regex
        new_content.gsub!(old_cost_breakdown_regex, new_cost_breakdown_css.strip)
        UI.messagebox("Successfully replaced old Cost Breakdown Table CSS block.", MB_OK, "AutoNestCut Stylesheet Update")
        changes_made = true
      else
        # If the old block isn't found, append the new one to the end of the file.
        # This handles cases where the block might have been removed or never existed.
        new_content += "\n\n" + new_cost_breakdown_css.strip
        UI.messagebox("Warning: Old Cost Breakdown Table CSS block not found. Appended new block to end of style.css.", MB_OK, "AutoNestCut Stylesheet Update")
        changes_made = true
      end

      # 3. Write back to file if changes were made
      if changes_made
        begin
          File.write(css_file_path, new_content)
          UI.messagebox("style.css updated successfully! Please restart SketchUp or reload any open web dialogs (e.g., AutoNestCut) to see the changes.", MB_OK, "AutoNestCut Stylesheet Update Success")
          return true
        rescue StandardError => e
          UI.messagebox("Error writing to style.css: #{e.message}\nPlease check file permissions for:\n#{css_file_path}", MB_OK, "AutoNestCut Stylesheet Update Error")
          return false
        end
      else
        UI.messagebox("No relevant CSS changes were needed or applied.", MB_OK, "AutoNestCut Stylesheet Update")
        return true
      end
    end # def self.update_stylesheet

  end # module Utils
end # module AutoNestCut

#<SyntaxError:"(eval):137: unterminated regexp meets end of file\nend # module AutoNestCut\n                        ^\n(eval):137: syntax error, unexpected end-of-input, expecting `end' or dummy end\nend # module AutoNestCut\n                        ^\n">
SketchUp:in `eval'
=> nil
module AutoNestCut
  module Utils
    # This method updates the style.css file with specific layout and alignment fixes for tables.
    # It ensures the Cost Breakdown table has proper width and all table cells are aligned correctly.
    def self.update_stylesheet
      # 1. Define the path to style.css
      # This assumes the script is in 'AutoNestCut/Utils/' and style.css is in 'AutoNestCut/html/'.
      # Adjust `File.dirname` if your 'html' folder is in a different relative location.
      extension_root = File.dirname(File.dirname(__FILE__)) # Go up two levels from current script location
      css_file_path = File.join(extension_root, 'html', 'style.css') # Assuming 'html' is directly under the extension root

      unless File.exist?(css_file_path)
        UI.messagebox("Error: style.css not found at:\n#{css_file_path}\nCannot apply updates. Please ensure the file exists.", MB_OK, "AutoNestCut Stylesheet Update")
        return false
      end

      # Read the original content of the stylesheet
      original_content = File.read(css_file_path)
      new_content = original_content.dup # Work on a duplicate

      # Flag to track if any changes were made
      changes_made = false

      # --- Modification 1: Comment out 'text-align: left;' from general 'th, td' block ---
      # This regex attempts to find the 'th, td { ... }' block and then modify the 'text-align'
      # property specifically within it.
      # Using a non-greedy match (.*?) to ensure it doesn't span across multiple CSS blocks.
      # The `m` flag allows `.` to match newlines, `^` and `$` match start/end of line.
      th_td_block_regex = /(th,\s*td\s*\{\s*)(.*?)(^\s*text-align:\s*left;\s*$)(.*?)\}/m

      if new_content =~ th_td_block_regex
        # Replace the matched 'text-align: left;' line with a commented-out version
        new_content.gsub!(th_td_block_regex) do |match|
          "#{Regexp.last_match(1)}#{Regexp.last_match(2)}/* #{Regexp.last_match(3).strip} */#{Regexp.last_match(4)}"
        end
        UI.messagebox("Successfully commented out 'text-align: left;' from general 'th, td' block.", MB_OK, "AutoNestCut Stylesheet Update")
        changes_made = true
      else
        UI.messagebox("Warning: 'text-align: left;' (or its containing 'th, td' block) not found in style.css. Skipping this modification.", MB_OK, "AutoNestCut Stylesheet Update")
      end

      # --- Modification 2: Replace the entire '#costBreakdownContainer' block ---
      # This block defines the new, corrected CSS for the Cost Breakdown table.
      # IMPORTANT: The `CSS_BLOCK` identifier below MUST be flush with the left margin
      # (no leading spaces) to correctly terminate the heredoc string.
      new_cost_breakdown_css = <<-CSS_BLOCK
/* Override for Cost Breakdown Table: Width and Alignment */
/* This section targets the table within the specific #costBreakdownContainer.
   It sets explicit column widths and ensures correct text alignment as per the desired layout. */

/* Ensure fixed table layout for the cost breakdown table, with highest specificity */
#costBreakdownContainer .table-wrapper table {
    width: 100% !important; /* Ensures table fills its parent (the .table-wrapper) */
    table-layout: fixed !important; /* Force fixed layout for predictable column widths */
    min-width: unset !important; /* Ensure no conflicting min-width is forcing it wider */
}

/* General cell padding, min-width removal, and text wrapping for cost breakdown cells */
#costBreakdownContainer .table-wrapper table th,
#costBreakdownContainer .table-wrapper table td {
    padding: 8px 12px !important; /* Maintain original padding */
    min-width: auto !important; /* Ensure no min-width forces individual cells wide */
    white-space: normal !important; /* Ensure text can wrap within cells */
    word-wrap: break-word !important; /* Ensures long words break to prevent overflow */
}

/* Define explicit widths and text alignment for each column in the Cost Breakdown table */
/* (Adjust percentages if your content significantly changes or you have more/fewer columns) */
#costBreakdownContainer .table-wrapper table th:first-child,
#costBreakdownContainer .table-wrapper table td:first-child {
    width: 40% !important; /* Material Name: Give more space for descriptions */
    text-align: left !important;
}

#costBreakdownContainer .table-wrapper table th:nth-child(2),
#costBreakdownContainer .table-wrapper table td:nth-child(2) {
    width: 15% !important; /* Parts Count: Generally smaller numbers */
    text-align: right !important;
}

#costBreakdownContainer .table-wrapper table th:nth-child(3),
#costBreakdownContainer .table-wrapper table td:nth-child(3) {
    width: 25% !important; /* Total Cost: Monetary values */
    text-align: right !important;
}

#costBreakdownContainer .table-wrapper table th:nth-child(4),
#costBreakdownContainer .table-wrapper table td:nth-child(4) {
    width: 20% !important; /* Percentage: Small values */
    text-align: right !important;
}
/* Total for columns: 40% + 15% + 25% + 20% = 100% */
CSS_BLOCK

      # Regex to find the *old* cost breakdown block.
      # It looks for the specific comment `/* Override for cost breakdown table - REVISION */`
      # and captures everything until the next `th { position: sticky;` rule or the end of the file.
      # Options: 'm' for multiline, 'x' for extended (allows comments and whitespace within the regex pattern itself).
      old_cost_breakdown_regex = %r{
        /\*\s*Override\s*for\s*cost\s*breakdown\s*table\s*-\s*REVISION\s*\*/ # Start comment marker within regex
        .*?                                                             # Non-greedy match for anything (the old CSS rules)
        (?=\s*th\s*\{\s*position:\s*sticky;|\Z)                         # Lookahead: ends before 'th { position: sticky;' or end of file
      }mx # Placed on its own line for clarity and to prevent parsing issues.

      if new_content =~ old_cost_breakdown_regex
        new_content.gsub!(old_cost_breakdown_regex, new_cost_breakdown_css.strip)
        UI.messagebox("Successfully replaced old Cost Breakdown Table CSS block.", MB_OK, "AutoNestCut Stylesheet Update")
        changes_made = true
      else
        # If the old block isn't found, append the new one to the end of the file.
        # This handles cases where the block might have been removed or never existed.
        new_content += "\n\n" + new_cost_breakdown_css.strip
        UI.messagebox("Warning: Old Cost Breakdown Table CSS block not found. Appended new block to end of style.css.", MB_OK, "AutoNestCut Stylesheet Update")
        changes_made = true
      end

      # 3. Write back to file if changes were made
      if changes_made
        begin
          File.write(css_file_path, new_content)
          UI.messagebox("style.css updated successfully! Please restart SketchUp or reload any open web dialogs (e.g., AutoNestCut) to see the changes.", MB_OK, "AutoNestCut Stylesheet Update Success")
          return true
        rescue StandardError => e
          UI.messagebox("Error writing to style.css: #{e.message}\nPlease check file permissions for:\n#{css_file_path}", MB_OK, "AutoNestCut Stylesheet Update Error")
          return false
        end
      else
        UI.messagebox("No relevant CSS changes were needed or applied.", MB_OK, "AutoNestCut Stylesheet Update")
        return true
      end
    end # def self.update_stylesheet

  end # module Utils
end # module AutoNestCut
#<SyntaxError:"(eval):134: unterminated regexp meets end of file\nend # module AutoNestCut\n                        ^\n(eval):134: syntax error, unexpected end-of-input, expecting `end' or dummy end\nend # module AutoNestCut\n                        ^\n">
SketchUp:in `eval'
=> nil

