# Save this file as 'autonestcut_stylesheet_updater.rb' in your specific temp_scripts directory:
# C:\Users\Administrator\Desktop\AUTOMATION\cutlist\AutoNestCut\AutoNestCut_Clean_Workspace\Extension\DEV_FILES\temp_scripts
# Ensure the final 'CSS_BLOCK' line (around line 122) is flush with the left margin (no leading whitespace).

module AutoNestCut
  module Utils
    # This method updates the style.css file with specific layout and alignment fixes for tables.
    # It ensures the Cost Breakdown table has proper width and all table cells are aligned correctly.
    def self.update_stylesheet
      # 1. Define the path to style.css
      # CORRECTED PATH LOGIC: Calculate extension_root based on the script's exact dev location.
      # The script is in `temp_scripts`, and `html` is under the main `AutoNestCut` folder,
      # which is 5 levels up from `temp_scripts`.
      current_script_dir = File.dirname(__FILE__)
      extension_root = File.expand_path('../../../../../', current_script_dir) # Go up 5 levels

      # Now, construct the path to style.css, assuming `html` is directly under this calculated extension_root.
      css_file_path = File.join(extension_root, 'html', 'style.css')

      unless File.exist?(css_file_path)
        UI.messagebox("Error: style.css not found at:\n#{css_file_path}\nCannot apply updates. Please ensure the file exists at this path.", MB_OK, "AutoNestCut Stylesheet Update")
        return false
      end

      # Read the original content of the stylesheet
      original_content = File.read(css_file_path)
      new_content = original_content.dup # Work on a duplicate

      # Flag to track if any changes were made
      changes_made = false

      # --- Modification 1: Ensure general 'th, td' block has 'text-align: initial;' ---
      th_td_block_regex = /(th,\s*td\s*\{\s*)(.*?)(^\s*text-align:\s*(left|initial|unset|right|center);?\s*$)?(.*?)\}/m

      if new_content =~ th_td_block_regex
        pre_text_align_content = Regexp.last_match(1) + Regexp.last_match(2)
        text_align_line = Regexp.last_match(3)
        post_text_align_content = Regexp.last_match(5)

        new_text_align_rule = "    text-align: initial;"

        if text_align_line
          new_th_td_block = "#{pre_text_align_content}#{new_text_align_rule}\n#{post_text_align_content}}"
        else
          new_th_td_block = "#{pre_text_align_content}\n#{new_text_align_rule}\n#{post_text_align_content}"
        end

        new_content.gsub!(th_td_block_regex, new_th_td_block)
        UI.messagebox("Successfully set 'text-align: initial;' in general 'th, td' block.", MB_OK, "AutoNestCut Stylesheet Update")
        changes_made = true
      else
        UI.messagebox("Warning: 'th, td' block not found in style.css. Skipping general text-align modification.", MB_OK, "AutoNestCut Stylesheet Update")
      end

      # --- Modification 2: Replace the entire '#costBreakdownContainer' block ---
      new_cost_breakdown_css = <<-CSS_BLOCK
/* Override for Cost Breakdown Section: Width and Alignment */
/* This section specifically targets the Cost Breakdown Summary text and the table. */

/* Style for the 'Cost Analysis Summary' div - this targets any direct child div of #costBreakdownContainer
   that is NOT the .table-wrapper and does not start with 'markdown-'.
   This ensures the summary text itself is constrained, wraps, and has proper styling. */
#costBreakdownContainer > div:not(.table-wrapper):not([class^="markdown-"]) {
    width: 100%; /* Ensures it fills its parent up to available space */
    max-width: 100%; /* Prevents it from exceeding parent's width */
    box-sizing: border-box;
    white-space: normal; /* Allows text to wrap within the summary div */
    word-wrap: break-word; /* Breaks long words if necessary */
    margin-bottom: 15px; /* Spacing below the summary text */
    padding: 8px 12px;
    background-color: #f8f9fa; /* Light background for visual separation */
    border: 1px solid #e9ecef;
    border-radius: 4px;
    font-size: 13px;
    color: #495057;
    text-align: left; /* Ensure summary text is left-aligned */
}

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

      old_cost_breakdown_regex = %r{
        /\*\s*Override\s*for\s*cost\s*breakdown\s*table\s*-\s*REVISION\s*\*/ # Start comment marker
        .*?                                                             # Non-greedy match for anything (the old CSS rules)
        (?=\s*th\s*\{\s*position:\s*sticky;|\Z)                         # Lookahead: ends before 'th { position: sticky;' or end of file
      }mx # m: multiline, x: extended (allows comments and whitespace in regex)

      if new_content =~ old_cost_breakdown_regex
        new_content.gsub!(old_cost_breakdown_regex, new_cost_breakdown_css.strip)
        UI.messagebox("Successfully replaced old Cost Breakdown Section CSS block.", MB_OK, "AutoNestCut Stylesheet Update")
        changes_made = true
      else
        new_content += "\n\n" + new_cost_breakdown_css.strip
        UI.messagebox("Warning: Old Cost Breakdown Section CSS block not found. Appended new block to end of style.css.", MB_OK, "AutoNestCut Stylesheet Update")
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
