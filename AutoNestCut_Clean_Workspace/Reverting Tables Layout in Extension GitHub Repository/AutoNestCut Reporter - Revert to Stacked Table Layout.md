# AutoNestCut Reporter - Revert to Stacked Table Layout

## Summary

This package contains the reporter files from **commit 44e376e** ("Update: description of your change"), which is the **last version BEFORE the side-by-side table layout was implemented**.

The side-by-side layout was introduced in **commit f8de204** ("Update: major updates"), which added CSS classes like `.side-by-side-tables` and changed the HTML structure to display the "Materials Used" and "Overall Summary" tables side-by-side instead of stacked (one above the other).

---

## Repository Information

- **Repository**: https://github.com/mike-ai-lab/AutoNestCutlist-main.git
- **Branch**: main
- **Commit with Stacked Layout**: 44e376e64218311cddecc2f2d7510cc20cf74c25
- **Commit with Side-by-Side Layout**: f8de204209307b5ac14ec449a05b4f480068c8f5
- **Date**: November 24, 2025

---

## Files Included

This package contains **4 files** from commit 44e376e:

1. **main.html** (62 KB)
   - Main reporter HTML file with stacked table layout
   - Path: `AutoNestCut_Clean_Workspace/Extension/AutoNestCut/ui/html/main.html`

2. **style.css** (26 KB)
   - CSS styles WITHOUT side-by-side table layout classes
   - Path: `AutoNestCut_Clean_Workspace/Extension/AutoNestCut/ui/html/style.css`

3. **table_customization.js** (21 KB)
   - JavaScript for table customization
   - Path: `AutoNestCut_Clean_Workspace/Extension/AutoNestCut/ui/html/table_customization.js`

4. **diagrams_report.js** (53 KB)
   - JavaScript for diagrams and report rendering
   - Path: `AutoNestCut_Clean_Workspace/Extension/AutoNestCut/ui/html/diagrams_report.js`

---

## What Changed in the Side-by-Side Implementation

In commit **f8de204**, the following changes were made:

### main.html Changes:
- Removed old stacked table structure
- Added new HTML structure with `.side-by-side-tables` container
- Modified template management section
- Changed button layouts to compact versions

### style.css Changes:
- Added `.side-by-side-tables` CSS class with flexbox/grid layout
- Added responsive design rules for side-by-side tables
- Multiple definitions for side-by-side layout (11 occurrences found)

### table_customization.js Changes:
- Updated to support the new side-by-side layout structure

### diagrams_report.js Changes:
- Minor text label changes (Average→Standard, High→Premium, Low→Budget)
- Added custom label support

---

## How to Revert

### Option 1: Replace Files Directly

1. Navigate to your extension directory:
   ```
   AutoNestCut_Clean_Workspace/Extension/AutoNestCut/ui/html/
   ```

2. **Backup your current files first** (important!):
   ```bash
   mkdir backup_side_by_side
   cp main.html style.css table_customization.js diagrams_report.js backup_side_by_side/
   ```

3. Replace the files with the ones from this package:
   ```bash
   cp /path/to/this/package/main.html .
   cp /path/to/this/package/style.css .
   cp /path/to/this/package/table_customization.js .
   cp /path/to/this/package/diagrams_report.js .
   ```

4. Test the extension in SketchUp to verify the tables are now stacked

### Option 2: Use Git to Revert

If you're using Git version control:

```bash
cd /path/to/AutoNestCutlist-main
git checkout 44e376e -- AutoNestCut_Clean_Workspace/Extension/AutoNestCut/ui/html/main.html
git checkout 44e376e -- AutoNestCut_Clean_Workspace/Extension/AutoNestCut/ui/html/style.css
git checkout 44e376e -- AutoNestCut_Clean_Workspace/Extension/AutoNestCut/ui/html/table_customization.js
git checkout 44e376e -- AutoNestCut_Clean_Workspace/Extension/AutoNestCut/ui/html/diagrams_report.js
```

---

## Verification

After reverting, the reporter should display:

✅ **Materials Used** table at the top (full width)
✅ **Overall Summary** table below it (full width)
✅ Tables stacked vertically, NOT side-by-side

❌ NO `.side-by-side-tables` CSS class in use
❌ NO horizontal layout for these two tables

---

## Commit Timeline

```
6cf475a - Initial backup: Working AutoNestCut extension with fixes (5 days ago)
   ↓
56d5ab9 - Phase 1: Unit System Consistency (5 days ago)
   ↓
d8feda4 - Add Phase 1 version identifiers to UI (5 days ago)
   ↓
8b11a4c - CRITICAL FIX: Add missing 'm' unit factor (5 days ago)
   ↓
6698abd - BEFORE INTEGRATION FEATURE (4 days ago)
   ↓
ec9eddf - BEFORE security (4 days ago)
   ↓
64fc6dd - Stable backup before new update (14 hours ago)
   ↓
44e376e - Update: description of your change (12 hours ago) ⬅️ **STACKED LAYOUT (USE THIS)**
   ↓
f8de204 - Update: major updates (10 hours ago) ⬅️ **SIDE-BY-SIDE LAYOUT (PROBLEMATIC)**
   ↓
49971f6 - Stable version snapshot (10 hours ago) - Current main
```

---

## Notes

- These files represent the **working state before the side-by-side implementation**
- The stacked layout is more traditional and may be more suitable for printing and readability
- If you encounter any issues after reverting, you can always restore from your backup
- Consider creating a Git branch before making changes for easy rollback

---

## Contact

For questions about this reversion:
- Repository: https://github.com/mike-ai-lab/AutoNestCutlist-main
- Developer: muhamad.shkeir@gmail.com (from repository README)

---

**Generated**: November 24, 2025
**Source Commit**: 44e376e64218311cddecc2f2d7510cc20cf74c25
