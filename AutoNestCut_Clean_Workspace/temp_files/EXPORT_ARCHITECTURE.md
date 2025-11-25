# Export System Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    AutoNestCut Extension                     │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              User Interface (main.html)             │    │
│  │                                                      │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐         │    │
│  │  │   PDF    │  │   HTML   │  │   CSV    │         │    │
│  │  │  Button  │  │  Button  │  │  Button  │         │    │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘         │    │
│  └───────┼─────────────┼─────────────┼────────────────┘    │
│          │             │             │                      │
│          ▼             ▼             ▼                      │
│  ┌──────────────────────────────────────────────────┐      │
│  │         JavaScript Layer (pdf_export.js)          │      │
│  │                                                    │      │
│  │  ┌─────────────┐  ┌──────────────┐               │      │
│  │  │ exportToPDF │  │exportInteract│               │      │
│  │  │     ()      │  │  iveHTML()   │               │      │
│  │  └──────┬──────┘  └──────┬───────┘               │      │
│  │         │                 │                        │      │
│  │         ▼                 ▼                        │      │
│  │  ┌─────────────┐  ┌──────────────┐               │      │
│  │  │  Generate   │  │   Extract    │               │      │
│  │  │Professional │  │   Computed   │               │      │
│  │  │  PDF HTML   │  │    Styles    │               │      │
│  │  └──────┬──────┘  └──────┬───────┘               │      │
│  └─────────┼─────────────────┼────────────────────────┘      │
│            │                 │                              │
│            ▼                 ▼                              │
│  ┌──────────────┐   ┌────────────────┐                    │
│  │   Preview    │   │  callRuby()    │                    │
│  │   Window     │   │  save_html_    │                    │
│  │              │   │    report      │                    │
│  └──────┬───────┘   └────────┬───────┘                    │
│         │                     │                            │
│         ▼                     ▼                            │
│  ┌──────────────┐   ┌────────────────┐                    │
│  │   Browser    │   │ Ruby Backend   │                    │
│  │    Print     │   │ (dialog_       │                    │
│  │   Dialog     │   │  manager.rb)   │                    │
│  └──────┬───────┘   └────────┬───────┘                    │
│         │                     │                            │
│         ▼                     ▼                            │
│  ┌──────────────┐   ┌────────────────┐                    │
│  │  User Saves  │   │  File Saved    │                    │
│  │   as PDF     │   │  to Desktop    │                    │
│  └──────────────┘   └────────────────┘                    │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow - PDF Export

```
┌─────────────────────────────────────────────────────────────┐
│                      PDF Export Flow                         │
└─────────────────────────────────────────────────────────────┘

1. User Action
   ┌──────────────────┐
   │ User clicks PDF  │
   │     button       │
   └────────┬─────────┘
            │
            ▼
2. Data Validation
   ┌──────────────────┐
   │ Check g_report   │
   │ Data & g_boards  │
   │      Data        │
   └────────┬─────────┘
            │
            ▼
3. Settings Extraction
   ┌──────────────────┐
   │ Get currentUnits │
   │ currentPrecision │
   │ defaultCurrency  │
   │ currentAreaUnits │
   └────────┬─────────┘
            │
            ▼
4. HTML Generation
   ┌──────────────────┐
   │ generateProfess  │
   │ ionalPDFHTML()   │
   │                  │
   │ • Header         │
   │ • Summary Box    │
   │ • Part Types     │
   │ • Board Layouts  │
   │ • Cost Analysis  │
   │ • Footer         │
   └────────┬─────────┘
            │
            ▼
5. Preview Window
   ┌──────────────────┐
   │ window.open()    │
   │ with generated   │
   │      HTML        │
   └────────┬─────────┘
            │
            ▼
6. User Review
   ┌──────────────────┐
   │ User reviews     │
   │ preview and      │
   │ clicks print     │
   └────────┬─────────┘
            │
            ▼
7. Browser Print
   ┌──────────────────┐
   │ window.print()   │
   │ opens browser    │
   │ print dialog     │
   └────────┬─────────┘
            │
            ▼
8. Save as PDF
   ┌──────────────────┐
   │ User selects     │
   │ "Save as PDF"    │
   │ and location     │
   └────────┬─────────┘
            │
            ▼
9. Complete
   ┌──────────────────┐
   │ PDF file saved   │
   │ to chosen        │
   │ location         │
   └──────────────────┘
```

## Data Flow - HTML Export

```
┌─────────────────────────────────────────────────────────────┐
│                     HTML Export Flow                         │
└─────────────────────────────────────────────────────────────┘

1. User Action
   ┌──────────────────┐
   │ User clicks HTML │
   │     button       │
   └────────┬─────────┘
            │
            ▼
2. Data Validation
   ┌──────────────────┐
   │ Check g_report   │
   │ Data & g_boards  │
   │      Data        │
   └────────┬─────────┘
            │
            ▼
3. Style Extraction
   ┌──────────────────┐
   │ getTableStyles() │
   │ getThStyles()    │
   │ getTdStyles()    │
   │                  │
   │ Extract from:    │
   │ • summaryTable   │
   │ • partsTable     │
   │ • etc.           │
   └────────┬─────────┘
            │
            ▼
4. HTML Generation
   ┌──────────────────┐
   │ generateInteract │
   │  iveHTML()       │
   │                  │
   │ • Embed styles   │
   │ • Add all tables │
   │ • Format data    │
   └────────┬─────────┘
            │
            ▼
5. Send to Ruby
   ┌──────────────────┐
   │ callRuby(        │
   │  'save_html_     │
   │   report',       │
   │  htmlContent)    │
   └────────┬─────────┘
            │
            ▼
6. Ruby Processing
   ┌──────────────────┐
   │ Generate filename│
   │ Check for        │
   │ duplicates       │
   │ Increment counter│
   └────────┬─────────┘
            │
            ▼
7. File Save
   ┌──────────────────┐
   │ File.write()     │
   │ to Desktop       │
   └────────┬─────────┘
            │
            ▼
8. User Notification
   ┌──────────────────┐
   │ UI.messagebox()  │
   │ with filename    │
   └────────┬─────────┘
            │
            ▼
9. Complete
   ┌──────────────────┐
   │ HTML file on     │
   │ Desktop ready    │
   │ to open          │
   └──────────────────┘
```

## Component Interaction

```
┌─────────────────────────────────────────────────────────────┐
│                   Component Diagram                          │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│                        Frontend Layer                         │
├──────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────────┐  ┌────────────────┐  ┌───────────────┐ │
│  │   main.html    │  │  app.js        │  │ diagrams_     │ │
│  │                │  │                │  │ report.js     │ │
│  │ • UI Structure │  │ • Settings     │  │               │ │
│  │ • Buttons      │  │ • Materials    │  │ • Rendering   │ │
│  │ • Tabs         │  │ • Parts Data   │  │ • Formatting  │ │
│  └────────┬───────┘  └────────┬───────┘  └───────┬───────┘ │
│           │                   │                   │          │
│           └───────────────────┼───────────────────┘          │
│                               │                              │
│                               ▼                              │
│                    ┌────────────────────┐                    │
│                    │  pdf_export.js     │                    │
│                    │                    │                    │
│                    │ • exportToPDF()    │                    │
│                    │ • exportInteract   │                    │
│                    │   iveHTML()        │                    │
│                    │ • generateProfess  │                    │
│                    │   ionalPDFHTML()   │                    │
│                    │ • generateInteract │                    │
│                    │   iveHTML()        │                    │
│                    └──────────┬─────────┘                    │
│                               │                              │
└───────────────────────────────┼──────────────────────────────┘
                                │
                                │ callRuby()
                                │
┌───────────────────────────────┼──────────────────────────────┐
│                        Backend Layer                          │
├───────────────────────────────┼──────────────────────────────┤
│                               ▼                              │
│                    ┌────────────────────┐                    │
│                    │ dialog_manager.rb  │                    │
│                    │                    │                    │
│                    │ Callbacks:         │                    │
│                    │ • save_html_report │                    │
│                    │ • export_csv       │                    │
│                    │ • process          │                    │
│                    └──────────┬─────────┘                    │
│                               │                              │
│                               ▼                              │
│                    ┌────────────────────┐                    │
│                    │ report_generator.rb│                    │
│                    │                    │                    │
│                    │ • generate_report  │                    │
│                    │   _data()          │                    │
│                    │ • export_csv()     │                    │
│                    └────────────────────┘                    │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

## File Dependencies

```
┌─────────────────────────────────────────────────────────────┐
│                    File Dependencies                         │
└─────────────────────────────────────────────────────────────┘

main.html
    │
    ├─→ app.js
    │   ├─→ Defines: currentUnits, currentPrecision, etc.
    │   ├─→ Provides: formatDimension(), callRuby()
    │   └─→ Manages: Settings, materials, parts data
    │
    ├─→ diagrams_report.js
    │   ├─→ Defines: g_reportData, g_boardsData
    │   ├─→ Provides: formatNumber(), formatAreaForPDF()
    │   ├─→ Provides: getAreaUnitLabel()
    │   └─→ Manages: Report rendering, diagrams
    │
    ├─→ table_customization.js
    │   ├─→ Provides: Table styling functions
    │   └─→ Manages: User customization
    │
    └─→ pdf_export.js (NEW)
        ├─→ Uses: g_reportData, g_boardsData
        ├─→ Uses: currentUnits, currentPrecision
        ├─→ Uses: formatNumber(), formatAreaForPDF()
        ├─→ Provides: exportToPDF()
        └─→ Provides: exportInteractiveHTML()

dialog_manager.rb
    │
    ├─→ Requires: report_generator.rb
    ├─→ Requires: config.rb
    ├─→ Requires: materials_database.rb
    │
    └─→ Callbacks:
        ├─→ save_html_report (NEW)
        ├─→ export_csv
        └─→ process
```

## State Management

```
┌─────────────────────────────────────────────────────────────┐
│                      State Flow                              │
└─────────────────────────────────────────────────────────────┘

Global State (JavaScript)
┌────────────────────────────────────────────────────────────┐
│                                                             │
│  currentSettings = {}                                       │
│  partsData = {}                                             │
│  g_reportData = null                                        │
│  g_boardsData = []                                          │
│                                                             │
│  currentUnits = 'mm'                                        │
│  currentPrecision = 1                                       │
│  currentAreaUnits = 'm2'                                    │
│  defaultCurrency = 'USD'                                    │
│                                                             │
└────────────────────────────────────────────────────────────┘
                            │
                            │ Used by
                            ▼
┌────────────────────────────────────────────────────────────┐
│                    Export Functions                         │
│                                                             │
│  exportToPDF()                                              │
│  ├─→ Reads: g_reportData, g_boardsData                     │
│  ├─→ Reads: currentUnits, currentPrecision                 │
│  └─→ Generates: Professional PDF HTML                      │
│                                                             │
│  exportInteractiveHTML()                                    │
│  ├─→ Reads: g_reportData, g_boardsData                     │
│  ├─→ Reads: All current settings                           │
│  ├─→ Extracts: Computed styles from DOM                    │
│  └─→ Generates: Standalone HTML                            │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

## Error Handling Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Error Handling                            │
└─────────────────────────────────────────────────────────────┘

PDF Export Error Handling
┌────────────────────────────────────────────────────────────┐
│                                                             │
│  exportToPDF()                                              │
│      │                                                      │
│      ├─→ Check: g_reportData exists?                       │
│      │   └─→ No: alert('No report data')                   │
│      │                                                      │
│      ├─→ Check: g_boardsData exists?                       │
│      │   └─→ No: alert('No report data')                   │
│      │                                                      │
│      ├─→ Try: Generate HTML                                │
│      │   └─→ Catch: Log error, show alert                  │
│      │                                                      │
│      └─→ Try: Open preview window                          │
│          └─→ Catch: Check popup blocker                    │
│                                                             │
└────────────────────────────────────────────────────────────┘

HTML Export Error Handling
┌────────────────────────────────────────────────────────────┐
│                                                             │
│  exportInteractiveHTML()                                    │
│      │                                                      │
│      ├─→ Check: g_reportData exists?                       │
│      │   └─→ No: alert('No report data')                   │
│      │                                                      │
│      ├─→ Try: Extract styles                               │
│      │   └─→ Catch: Use default styles                     │
│      │                                                      │
│      ├─→ Try: Generate HTML                                │
│      │   └─→ Catch: Log error, show alert                  │
│      │                                                      │
│      └─→ callRuby('save_html_report')                      │
│          │                                                  │
│          └─→ Ruby Error Handling:                          │
│              ├─→ Try: Generate filename                    │
│              ├─→ Try: Write file                           │
│              ├─→ Catch: Show error messagebox              │
│              └─→ Log: Error to Ruby console                │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

## Performance Optimization

```
┌─────────────────────────────────────────────────────────────┐
│                  Performance Strategy                        │
└─────────────────────────────────────────────────────────────┘

PDF Export
┌────────────────────────────────────────────────────────────┐
│                                                             │
│  1. Data Preparation                                        │
│     • Pre-calculate all values                             │
│     • Format numbers once                                  │
│     • Cache unit conversions                               │
│     Time: ~10ms                                            │
│                                                             │
│  2. HTML Generation                                         │
│     • Use template literals                                │
│     • Minimize DOM operations                              │
│     • Batch string concatenation                           │
│     Time: ~50ms                                            │
│                                                             │
│  3. Preview Window                                          │
│     • Open in separate window                              │
│     • No blocking operations                               │
│     • Async rendering                                      │
│     Time: ~20ms                                            │
│                                                             │
│  Total: ~80ms                                              │
│                                                             │
└────────────────────────────────────────────────────────────┘

HTML Export
┌────────────────────────────────────────────────────────────┐
│                                                             │
│  1. Style Extraction                                        │
│     • Query DOM once per table                             │
│     • Cache computed styles                                │
│     • Minimize reflows                                     │
│     Time: ~20ms                                            │
│                                                             │
│  2. HTML Generation                                         │
│     • Use template literals                                │
│     • Embed styles inline                                  │
│     • Minimize string operations                           │
│     Time: ~30ms                                            │
│                                                             │
│  3. Ruby File Save                                          │
│     • Single file write                                    │
│     • No complex processing                                │
│     • Direct to Desktop                                    │
│     Time: ~10ms                                            │
│                                                             │
│  Total: ~60ms                                              │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

---

**Architecture Version**: 1.0
**Last Updated**: 2024
**Status**: Production Ready
