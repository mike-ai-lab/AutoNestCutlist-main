# PDF & HTML Export - Complete Reimplementation Guide

## Overview

The PDF and HTML export functionality has been completely reimplemented to provide professional, print-ready reports that match the extension's styling and user preferences.

## What's New

### Professional PDF Export

1. **Preview Window**: Before printing/saving, a preview window opens showing the exact PDF that will be generated
2. **Professional Layout**: 
   - Clean, modern design with proper typography
   - Color-coded sections with gradient headers
   - Proper page breaks for printing
   - Professional summary boxes with statistics
   - Detailed cost analysis tables
   - Board layout summaries with visual hierarchy

3. **User Settings Respected**:
   - Uses current units (mm, cm, m, in, ft)
   - Applies current precision settings
   - Shows correct currency symbols
   - Displays area units as configured

4. **Print-Ready**:
   - A4 page size with proper margins
   - Print button in preview window
   - Optimized for both screen viewing and printing
   - Automatic page breaks between sections

### Interactive HTML Export

1. **Exact Styling Match**: The exported HTML file matches the user's table customization settings:
   - Font sizes
   - Cell padding
   - Colors (headers, text, borders)
   - Text alignment
   - Border styles

2. **Fully Standalone**: The HTML file is completely self-contained with:
   - All styles embedded
   - No external dependencies
   - Works offline
   - Can be shared via email

3. **Interactive Features**:
   - Hover effects on table rows
   - Clickable part IDs (in future versions)
   - Responsive layout
   - Professional formatting

## How to Use

### Exporting PDF

1. Generate your cut list and view the report
2. Click the **Print / Save PDF** button (printer icon)
3. A preview window opens showing the exact PDF
4. Click the **Print / Save PDF** button in the preview window
5. Choose "Save as PDF" in your print dialog
6. Select destination and save

### Exporting HTML

1. Generate your cut list and view the report
2. Click the **Export Interactive HTML** button (code icon)
3. The HTML file is automatically saved to your Desktop
4. File naming: `AutoNestCut_Report_[ModelName]_[Counter].html`
5. Open the file in any web browser

## Technical Details

### File Structure

```
ui/html/
├── pdf_export.js          # New PDF export module
├── main.html              # Updated to include pdf_export.js
└── diagrams_report.js     # Contains helper functions

exporters/
└── report_generator.rb    # Updated to delegate PDF to frontend

ui/
└── dialog_manager.rb      # Added save_html_report callback
```

### Key Functions

#### pdf_export.js

- `exportToPDF()`: Main entry point for PDF export
- `generateProfessionalPDFHTML()`: Creates the complete PDF HTML structure
- `exportInteractiveHTML()`: Main entry point for HTML export
- `generateInteractiveHTML()`: Creates standalone HTML with user's styling

#### Helper Functions (from diagrams_report.js)

- `formatNumber(value, precision)`: Formats numbers with correct precision
- `formatAreaForPDF(areaMM2)`: Converts and formats area values
- `getAreaUnitLabel()`: Returns proper area unit label (m², cm², etc.)

### Styling Extraction

The HTML export extracts computed styles from the current UI tables:

```javascript
const getTableStyles = (table) => {
    const computed = window.getComputedStyle(table);
    return `
        font-size: ${computed.fontSize};
        border-collapse: ${computed.borderCollapse};
    `;
};
```

This ensures the exported HTML exactly matches what the user sees in the extension.

## Customization

### Modifying PDF Layout

Edit `pdf_export.js` → `generateProfessionalPDFHTML()`:

- Change colors in the `<style>` section
- Modify section order in the HTML body
- Adjust spacing and margins
- Add/remove sections

### Modifying HTML Export

Edit `pdf_export.js` → `generateInteractiveHTML()`:

- Adjust which tables are included
- Modify the layout structure
- Add custom JavaScript for interactivity
- Change the styling extraction logic

## Troubleshooting

### PDF Preview Not Opening

**Issue**: Preview window doesn't open
**Solution**: Check browser popup blocker settings

### HTML File Not Saving

**Issue**: No file appears on Desktop
**Solution**: 
1. Check Ruby console for errors
2. Verify Desktop path is accessible
3. Check file permissions

### Styling Not Matching

**Issue**: Exported HTML doesn't match UI
**Solution**:
1. Ensure table customization is applied before export
2. Check that `window.getComputedStyle()` is supported
3. Verify CSS specificity isn't overriding styles

### Missing Data in Export

**Issue**: Some data missing from export
**Solution**:
1. Ensure report is fully generated before export
2. Check `g_reportData` and `g_boardsData` are populated
3. Verify all required fields exist in data structure

## Future Enhancements

### Planned Features

1. **PDF Direct Save**: Save PDF directly without print dialog
2. **Custom Templates**: User-defined PDF/HTML templates
3. **Batch Export**: Export multiple reports at once
4. **Email Integration**: Send reports directly via email
5. **Cloud Storage**: Save to Google Drive, Dropbox, etc.

### Interactive HTML Enhancements

1. **3D Part Viewer**: Embedded 3D visualization of parts
2. **Filtering**: Filter tables by material, size, etc.
3. **Sorting**: Click column headers to sort
4. **Search**: Search for specific parts or materials
5. **Print Optimization**: Separate print stylesheet

## Code Examples

### Adding a New Section to PDF

```javascript
// In generateProfessionalPDFHTML(), add before footer:
<h2 class="section-title">Custom Section</h2>
<table class="data-table">
    <thead>
        <tr><th>Column 1</th><th>Column 2</th></tr>
    </thead>
    <tbody>
        ${customData.map(item => `
            <tr>
                <td>${item.field1}</td>
                <td>${item.field2}</td>
            </tr>
        `).join('')}
    </tbody>
</table>
```

### Extracting Additional Styles

```javascript
// In generateInteractiveHTML():
const getRowStyles = (table) => {
    const tr = table.querySelector('tbody tr');
    if (!tr) return '';
    const computed = window.getComputedStyle(tr);
    return `
        background: ${computed.backgroundColor};
        height: ${computed.height};
    `;
};
```

## Best Practices

1. **Always Preview**: Check the preview before saving PDF
2. **Test Exports**: Verify exported files open correctly
3. **Backup Data**: Keep original SketchUp files
4. **Version Control**: Track changes to export templates
5. **User Feedback**: Collect feedback on export quality

## Support

For issues or questions:
- Email: muhamad.shkeir@gmail.com
- Check console for error messages
- Review this guide for troubleshooting steps

---

**Last Updated**: 2024
**Version**: 2.7.0
**Author**: Int. Arch. M.Shkeir
