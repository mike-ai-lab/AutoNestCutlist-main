# Export Quick Reference Card

## PDF Export (Print / Save PDF Button)

### Steps
1. Click **🖨️ Print / Save PDF** button in Report tab
2. Preview window opens automatically
3. Review the report in preview
4. Click **🖨️ Print / Save PDF** button in preview window
5. In print dialog, select "Save as PDF"
6. Choose location and filename
7. Click Save

### What You Get
- Professional A4-sized report
- Color-coded sections
- All tables properly formatted
- Cost analysis
- Board layouts
- Summary statistics

### Settings Applied
- ✅ Your current units (mm, cm, m, in, ft)
- ✅ Your precision settings (0, 1, 2, or 3 decimals)
- ✅ Your currency (USD, EUR, SAR, etc.)
- ✅ Your area units (mm², cm², m², in², ft²)

---

## HTML Export (Export Interactive HTML Button)

### Steps
1. Click **</>  Export Interactive HTML** button in Report tab
2. File automatically saves to Desktop
3. Success message shows filename
4. Open file in any web browser

### What You Get
- Standalone HTML file
- All your table customizations applied
- Same colors, fonts, and styling as UI
- Works offline
- Can be shared via email

### File Location
- **Windows**: `C:\Users\[YourName]\Desktop\AutoNestCut_Report_[ModelName]_[Number].html`
- **Mac**: `/Users/[YourName]/Desktop/AutoNestCut_Report_[ModelName]_[Number].html`

### Settings Applied
- ✅ Your table font sizes
- ✅ Your table colors
- ✅ Your cell padding
- ✅ Your text alignment
- ✅ Your border styles
- ✅ All unit/precision/currency settings

---

## CSV Export (Export CSV Report Button)

### Steps
1. Click **📄 Export CSV Report** button in Report tab
2. File automatically saves to Desktop
3. Success message shows filename
4. Open in Excel, Google Sheets, or any spreadsheet app

### What You Get
- Comma-separated values file
- All data in tabular format
- Easy to import into other software
- Can be edited in spreadsheet apps

---

## Tips & Tricks

### For Best PDF Results
- Use landscape orientation for wide tables
- Adjust browser zoom if needed (Ctrl/Cmd + or -)
- Check preview before saving
- Use "Save as PDF" not "Print to PDF" for best quality

### For Best HTML Results
- Customize tables BEFORE exporting
- Apply global table settings for consistency
- Test the HTML file in your browser before sharing
- HTML files are small and easy to email

### Customizing Before Export
1. Click **⚙️ Settings** button
2. Adjust units, precision, currency
3. Click **🎨 Global Table Settings** for table styling
4. Apply changes
5. Then export

---

## Troubleshooting

### PDF Preview Doesn't Open
**Problem**: Popup blocker
**Fix**: Allow popups for SketchUp in browser settings

### HTML File Not on Desktop
**Problem**: File save error
**Fix**: Check SketchUp Ruby Console for errors

### Wrong Units in Export
**Problem**: Settings not applied
**Fix**: Change settings → Click update → Then export

### Tables Look Different in HTML
**Problem**: Exported before applying customization
**Fix**: Apply table settings → Then export

---

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Print Preview | Ctrl/Cmd + P (in preview window) |
| Close Preview | Alt + F4 / Cmd + W |
| Zoom Preview | Ctrl/Cmd + / - |

---

## File Naming

### PDF Files
- You choose the name when saving
- Recommended: `ProjectName_CutList_Date.pdf`

### HTML Files
- Auto-named: `AutoNestCut_Report_ModelName_1.html`
- Counter increments if file exists
- Example: `AutoNestCut_Report_Kitchen_1.html`

### CSV Files
- Auto-named: `Cutting_List_ModelName_1.csv`
- Counter increments if file exists
- Example: `Cutting_List_Kitchen_1.csv`

---

## What's Included in Each Export

### PDF Export Includes
✅ Executive Summary
✅ Unique Part Types table
✅ Board Layout Summary (all boards)
✅ Cost Analysis table
✅ Material Requirements
✅ Professional formatting
✅ Page breaks for printing

### HTML Export Includes
✅ Overall Summary table
✅ Unique Part Types table
✅ Sheet Inventory Summary table
✅ Cut List & Part Details
✅ Interactive styling
✅ Hover effects

### CSV Export Includes
✅ Unique Part Types
✅ Parts Placed (detailed list)
✅ Boards Summary
✅ Overall Summary
✅ Raw data (no formatting)

---

## Best Practices

1. **Always Preview PDF** before saving
2. **Customize First** then export
3. **Check Settings** (units, precision, currency)
4. **Test HTML** in browser before sharing
5. **Keep Originals** - Don't delete SketchUp file
6. **Organize Files** - Use consistent naming
7. **Backup Exports** - Save to cloud storage

---

## Quick Comparison

| Feature | PDF | HTML | CSV |
|---------|-----|------|-----|
| Professional Layout | ✅ | ✅ | ❌ |
| Editable | ❌ | ❌ | ✅ |
| Print-Ready | ✅ | ⚠️ | ❌ |
| Shareable | ✅ | ✅ | ✅ |
| Interactive | ❌ | ⚠️ | ❌ |
| File Size | Medium | Small | Tiny |
| Opens In | PDF Reader | Browser | Spreadsheet |

✅ = Yes, ⚠️ = Partial, ❌ = No

---

## Need Help?

📧 Email: muhamad.shkeir@gmail.com
📖 Full Guide: See `PDF_HTML_EXPORT_GUIDE.md`
🐛 Issues: Check Ruby Console for errors

---

**Version**: 2.7.0
**Last Updated**: 2024
