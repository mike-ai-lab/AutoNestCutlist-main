// Table customization functionality
let currentTableId = null;
let tableSettings = {};
let globalTableSettings = {
    fontSize: '14px',
    cellPadding: '8px 12px',
    headerBg: '#f5f5f5',
    headerColor: '#000000',
    borderWidth: '1px',
    borderColor: '#d0d7de',
    textAlign: 'left',
    verticalAlign: 'middle',
    textWrap: 'normal',
    rowHover: '#f6f8fa'
};

// Initialize table customization
function initTableCustomization() {
    // Load saved settings
    loadTableSettings();
    
    // Add resize handles to all tables
    addResizeHandlesToTables();
    
    // Apply saved settings
    applyAllTableSettings();
}

// Open table customization panel
function openTableCustomization(tableId) {
    currentTableId = tableId;
    const panel = document.getElementById('tableCustomizationPanel');
    const overlay = document.querySelector('.modal-overlay');
    const title = document.getElementById('panelTitle');
    
    title.textContent = `Settings: ${getTableDisplayName(tableId)}`;
    panel.classList.add('active');
    overlay.style.display = 'block';
    
    // Load current settings for this table
    loadTableSettingsToPanel(tableId);
}

// Close table customization panel
function closeTableCustomization() {
    const panel = document.getElementById('tableCustomizationPanel');
    const overlay = document.querySelector('.modal-overlay');
    
    panel.classList.remove('active');
    overlay.style.display = 'none';
    currentTableId = null;
}

// Toggle global table settings
function toggleGlobalTableSettings() {
    const controls = document.getElementById('globalTableControls');
    controls.classList.toggle('active');
}

// Get display name for table
function getTableDisplayName(tableId) {
    const names = {
        'materialsUsedTable': 'Materials Used',
        'summaryTable': 'Summary',
        'uniquePartTypesTable': 'Part Types',
        'sheetInventoryTable': 'Sheet Inventory',
        'partsTable': 'Parts List'
    };
    return names[tableId] || tableId;
}

// Load table settings to panel
function loadTableSettingsToPanel(tableId) {
    const settings = tableSettings[tableId] || {};
    
    document.getElementById('tableFontSize').value = settings.fontSize || globalTableSettings.fontSize;
    document.getElementById('tableCellPadding').value = settings.cellPadding || globalTableSettings.cellPadding;
    document.getElementById('tableHeaderBg').value = settings.headerBg || globalTableSettings.headerBg;
    document.getElementById('tableHeaderColor').value = settings.headerColor || globalTableSettings.headerColor;
    document.getElementById('tableRowHover').value = settings.rowHover || globalTableSettings.rowHover;
    document.getElementById('tableTextAlign').value = settings.textAlign || globalTableSettings.textAlign;
    document.getElementById('tableVerticalAlign').value = settings.verticalAlign || globalTableSettings.verticalAlign;
    document.getElementById('tableTextWrap').value = settings.textWrap || globalTableSettings.textWrap;
    document.getElementById('tableBorderWidth').value = settings.borderWidth || globalTableSettings.borderWidth;
    document.getElementById('tableBorderColor').value = settings.borderColor || globalTableSettings.borderColor;
}

// Apply table setting
function applyTableSetting(property, value) {
    if (!currentTableId) return;
    
    // Initialize table settings if not exists
    if (!tableSettings[currentTableId]) {
        tableSettings[currentTableId] = {};
    }
    
    // Update setting
    tableSettings[currentTableId][property] = value;
    
    // Merge with global settings and apply
    const mergedSettings = { ...globalTableSettings, ...tableSettings[currentTableId] };
    applySettingsToTable(currentTableId, mergedSettings);
    
    // Save settings
    saveTableSettings();
}

// Apply global table setting
function applyGlobalTableSetting(property, value) {
    globalTableSettings[property] = value;
    
    // Apply to all tables immediately
    const tableIds = ['materialsUsedTable', 'summaryTable', 'uniquePartTypesTable', 'sheetInventoryTable', 'partsTable'];
    tableIds.forEach(tableId => {
        const table = document.getElementById(tableId);
        if (table) {
            // Merge individual settings with global for this table
            const mergedSettings = { ...globalTableSettings, ...(tableSettings[tableId] || {}) };
            applySettingsToTable(tableId, mergedSettings);
        }
    });
    
    // Update global controls
    updateGlobalControls();
    
    // Save settings
    saveTableSettings();
}

// Apply settings to specific table
function applySettingsToTable(tableId, settings) {
    const table = document.getElementById(tableId);
    if (!table) return;
    
    const fontSize = settings.fontSize || globalTableSettings.fontSize;
    const cellPadding = settings.cellPadding || globalTableSettings.cellPadding;
    const headerBg = settings.headerBg || globalTableSettings.headerBg;
    const headerColor = settings.headerColor || globalTableSettings.headerColor;
    const rowHover = settings.rowHover || globalTableSettings.rowHover;
    const textAlign = settings.textAlign || globalTableSettings.textAlign;
    const verticalAlign = settings.verticalAlign || globalTableSettings.verticalAlign;
    const textWrap = settings.textWrap || globalTableSettings.textWrap;
    const borderWidth = settings.borderWidth || globalTableSettings.borderWidth;
    const borderColor = settings.borderColor || globalTableSettings.borderColor;
    
    // Apply font size to table
    table.style.fontSize = fontSize;
    
    // Apply to all cells (th and td)
    const allCells = table.querySelectorAll('th, td');
    allCells.forEach(cell => {
        cell.style.setProperty('padding', cellPadding, 'important');
        cell.style.setProperty('text-align', textAlign, 'important');
        cell.style.setProperty('vertical-align', verticalAlign, 'important');
        
        // Handle text wrapping
        if (textWrap === 'nowrap') {
            cell.style.setProperty('white-space', 'nowrap', 'important');
            cell.style.setProperty('overflow', 'hidden', 'important');
            cell.style.setProperty('text-overflow', 'ellipsis', 'important');
            cell.style.setProperty('word-wrap', 'normal', 'important');
        } else if (textWrap === 'break-word') {
            cell.style.setProperty('white-space', 'pre-wrap', 'important');
            cell.style.setProperty('overflow', 'hidden', 'important');
            cell.style.setProperty('text-overflow', 'clip', 'important');
            cell.style.setProperty('word-wrap', 'break-word', 'important');
            cell.style.setProperty('word-break', 'break-all', 'important');
        } else { // normal wrap
            cell.style.setProperty('white-space', 'normal', 'important');
            cell.style.setProperty('overflow', 'visible', 'important');
            cell.style.setProperty('text-overflow', 'clip', 'important');
            cell.style.setProperty('word-wrap', 'break-word', 'important');
        }
        
        cell.style.setProperty('border-bottom-width', borderWidth, 'important');
        cell.style.setProperty('border-bottom-color', borderColor, 'important');
    });
    
    // Apply header-specific styles with !important
    const headers = table.querySelectorAll('th');
    headers.forEach(header => {
        header.style.setProperty('background-color', headerBg, 'important');
        header.style.setProperty('color', headerColor, 'important');
        header.style.setProperty('text-align', textAlign, 'important');
        
        // Update resize handle color to match header
        const handle = header.querySelector('.column-resize-handle');
        if (handle) {
            const darkerBg = darkenColor(headerBg, 20);
            handle.style.setProperty('background', `${darkerBg}66`, 'important'); // 40% opacity
            handle.style.setProperty('border-right-color', darkerBg, 'important');
        }
    });
    
    // Store hover color for dynamic application
    table.setAttribute('data-hover-color', rowHover);
    
    // Apply hover effect
    applyHoverEffect(table, rowHover);
}

// Apply all table settings
function applyAllTableSettings() {
    const tableIds = ['materialsUsedTable', 'summaryTable', 'uniquePartTypesTable', 'sheetInventoryTable', 'partsTable'];
    tableIds.forEach(tableId => {
        const table = document.getElementById(tableId);
        if (table) {
            // Merge global and individual settings
            const mergedSettings = { ...globalTableSettings, ...(tableSettings[tableId] || {}) };
            applySettingsToTable(tableId, mergedSettings);
        }
    });
}

// Reset table settings
function resetTableSettings() {
    if (!currentTableId) return;
    
    // Clear individual settings
    delete tableSettings[currentTableId];
    
    // Apply global settings only
    applySettingsToTable(currentTableId, globalTableSettings);
    
    // Update panel
    loadTableSettingsToPanel(currentTableId);
    
    // Save settings
    saveTableSettings();
}

// Apply all global settings
function applyAllGlobalSettings() {
    // Force apply global settings to all tables
    const tableIds = ['materialsUsedTable', 'summaryTable', 'uniquePartTypesTable', 'sheetInventoryTable', 'partsTable'];
    tableIds.forEach(tableId => {
        const table = document.getElementById(tableId);
        if (table) {
            applySettingsToTable(tableId, globalTableSettings);
        }
    });
    
    // Save settings
    saveTableSettings();
    
    // Show feedback
    showApplyFeedback('Global settings applied to all tables!');
}

// Apply current table settings
function applyCurrentTableSettings() {
    if (!currentTableId) return;
    
    const mergedSettings = { ...globalTableSettings, ...(tableSettings[currentTableId] || {}) };
    applySettingsToTable(currentTableId, mergedSettings);
    
    // Save settings
    saveTableSettings();
    
    // Show feedback
    showApplyFeedback(`Settings applied to ${getTableDisplayName(currentTableId)}!`);
}

// Darken color utility function
function darkenColor(color, percent) {
    // Convert hex to RGB
    let r, g, b;
    if (color.startsWith('#')) {
        const hex = color.slice(1);
        r = parseInt(hex.substr(0, 2), 16);
        g = parseInt(hex.substr(2, 2), 16);
        b = parseInt(hex.substr(4, 2), 16);
    } else if (color.startsWith('rgb')) {
        const matches = color.match(/\d+/g);
        r = parseInt(matches[0]);
        g = parseInt(matches[1]);
        b = parseInt(matches[2]);
    } else {
        return color; // Return original if can't parse
    }
    
    // Darken by percentage
    r = Math.max(0, Math.floor(r * (100 - percent) / 100));
    g = Math.max(0, Math.floor(g * (100 - percent) / 100));
    b = Math.max(0, Math.floor(b * (100 - percent) / 100));
    
    return `rgb(${r}, ${g}, ${b})`;
}

// Apply current table settings to global
function applyToGlobal() {
    if (!currentTableId || !tableSettings[currentTableId]) return;
    
    // Copy individual settings to global
    const individualSettings = tableSettings[currentTableId];
    Object.keys(individualSettings).forEach(key => {
        if (key !== 'columnWidths') { // Don't copy column widths
            globalTableSettings[key] = individualSettings[key];
        }
    });
    
    // Apply to all tables
    applyAllGlobalSettings();
    
    // Update global controls
    updateGlobalControls();
    
    // Show feedback
    showApplyFeedback(`${getTableDisplayName(currentTableId)} settings applied globally!`);
}

// Show apply feedback
function showApplyFeedback(message) {
    // Create or update feedback element
    let feedback = document.getElementById('applyFeedback');
    if (!feedback) {
        feedback = document.createElement('div');
        feedback.id = 'applyFeedback';
        feedback.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: #28a745;
            color: white;
            padding: 12px 20px;
            border-radius: 6px;
            font-size: 14px;
            font-weight: 600;
            z-index: 10000;
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
            transform: translateX(100%);
            transition: transform 0.3s ease;
        `;
        document.body.appendChild(feedback);
    }
    
    feedback.textContent = message;
    feedback.style.transform = 'translateX(0)';
    
    // Hide after 3 seconds
    setTimeout(() => {
        feedback.style.transform = 'translateX(100%)';
    }, 3000);
}

// Reset all table settings
function resetAllTableSettings() {
    // Clear all settings
    tableSettings = {};
    globalTableSettings = {
        fontSize: '14px',
        cellPadding: '8px 12px',
        headerBg: '#f5f5f5',
        headerColor: '#000000',
        borderWidth: '1px',
        borderColor: '#d0d7de',
        textAlign: 'left',
        verticalAlign: 'middle',
        textWrap: 'normal',
        rowHover: '#f6f8fa'
    };
    
    // Apply to all tables
    applyAllTableSettings();
    
    // Update controls
    updateGlobalControls();
    
    // Save settings
    saveTableSettings();
    
    // Show feedback
    showApplyFeedback('All table settings reset to defaults!');
}

// Update global controls
function updateGlobalControls() {
    const controls = {
        'globalFontSize': globalTableSettings.fontSize,
        'globalCellPadding': globalTableSettings.cellPadding,
        'globalHeaderBg': globalTableSettings.headerBg,
        'globalHeaderColor': globalTableSettings.headerColor,
        'globalRowHover': globalTableSettings.rowHover,
        'globalTextAlign': globalTableSettings.textAlign,
        'globalVerticalAlign': globalTableSettings.verticalAlign,
        'globalTextWrap': globalTableSettings.textWrap,
        'globalBorderWidth': globalTableSettings.borderWidth,
        'globalBorderColor': globalTableSettings.borderColor
    };
    
    Object.keys(controls).forEach(id => {
        const element = document.getElementById(id);
        if (element && controls[id]) {
            element.value = controls[id];
        }
    });
}

// Add resize handles to tables
function addResizeHandlesToTables() {
    const tables = document.querySelectorAll('.table-with-controls table');
    tables.forEach(table => {
        // Only add handles if not already added
        if (!table.querySelector('.column-resize-handle')) {
            addResizeHandlesToTable(table);
        }
    });
}

// Add resize handles to specific table
function addResizeHandlesToTable(table) {
    const headers = table.querySelectorAll('th');
    headers.forEach((header, index) => {
        if (index < headers.length - 1) { // Don't add to last column
            const handle = document.createElement('div');
            handle.className = 'column-resize-handle';
            handle.title = 'Drag to resize column';
            
            // Add multiple event listeners for better responsiveness
            handle.addEventListener('mousedown', (e) => startResize(e, table, index));
            handle.addEventListener('mouseenter', () => {
                const headerBg = window.getComputedStyle(header).backgroundColor;
                const darkerBg = darkenColor(headerBg, 30);
                handle.style.background = darkerBg;
            });
            handle.addEventListener('mouseleave', () => {
                if (!handle.classList.contains('resizing')) {
                    const headerBg = window.getComputedStyle(header).backgroundColor;
                    const darkerBg = darkenColor(headerBg, 20);
                    handle.style.background = `${darkerBg}66`; // 40% opacity
                }
            });
            
            header.appendChild(handle);
        }
    });
}

// Start column resize
function startResize(e, table, columnIndex) {
    e.preventDefault();
    const startX = e.clientX;
    const startWidth = table.querySelectorAll('th')[columnIndex].offsetWidth;
    
    const handle = e.target;
    handle.classList.add('resizing');
    
    function doResize(e) {
        const diff = e.clientX - startX;
        const newWidth = Math.max(50, startWidth + diff); // Minimum 50px
        
        // Update column width
        const headers = table.querySelectorAll('th');
        const cells = table.querySelectorAll('td');
        
        headers[columnIndex].style.width = newWidth + 'px';
        
        // Update corresponding cells
        const rows = table.querySelectorAll('tr');
        rows.forEach(row => {
            const cell = row.children[columnIndex];
            if (cell) {
                cell.style.width = newWidth + 'px';
            }
        });
    }
    
    function stopResize() {
        handle.classList.remove('resizing');
        document.removeEventListener('mousemove', doResize);
        document.removeEventListener('mouseup', stopResize);
        
        // Save column widths
        saveColumnWidths(table);
    }
    
    document.addEventListener('mousemove', doResize);
    document.addEventListener('mouseup', stopResize);
}

// Save column widths
function saveColumnWidths(table) {
    const tableId = table.id;
    if (!tableId) return;
    
    const headers = table.querySelectorAll('th');
    const widths = Array.from(headers).map(th => th.style.width || 'auto');
    
    if (!tableSettings[tableId]) {
        tableSettings[tableId] = {};
    }
    tableSettings[tableId].columnWidths = widths;
    
    saveTableSettings();
}

// Apply column widths
function applyColumnWidths(table) {
    const tableId = table.id;
    if (!tableId || !tableSettings[tableId] || !tableSettings[tableId].columnWidths) return;
    
    const headers = table.querySelectorAll('th');
    const widths = tableSettings[tableId].columnWidths;
    
    headers.forEach((header, index) => {
        if (widths[index] && widths[index] !== 'auto') {
            header.style.width = widths[index];
            
            // Apply to corresponding cells
            const rows = table.querySelectorAll('tr');
            rows.forEach(row => {
                const cell = row.children[index];
                if (cell) {
                    cell.style.width = widths[index];
                }
            });
        }
    });
}

// Save table settings to localStorage
function saveTableSettings() {
    try {
        localStorage.setItem('autoNestCutTableSettings', JSON.stringify({
            global: globalTableSettings,
            individual: tableSettings
        }));
    } catch (e) {
        console.warn('Could not save table settings:', e);
    }
}

// Load table settings from localStorage
function loadTableSettings() {
    try {
        const saved = localStorage.getItem('autoNestCutTableSettings');
        if (saved) {
            const data = JSON.parse(saved);
            if (data.global) {
                globalTableSettings = { ...globalTableSettings, ...data.global };
            }
            if (data.individual) {
                tableSettings = data.individual;
            }
        }
    } catch (e) {
        console.warn('Could not load table settings:', e);
    }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    // Delay initialization to ensure tables are rendered
    setTimeout(() => {
        initTableCustomization();
    }, 500);
});

// Also initialize when window loads (fallback)
window.addEventListener('load', function() {
    setTimeout(() => {
        initTableCustomization();
    }, 1000);
});

// Apply hover effect to table
function applyHoverEffect(table, hoverColor) {
    // Remove existing hover styles
    const existingStyle = document.getElementById(`hover-style-${table.id}`);
    if (existingStyle) {
        existingStyle.remove();
    }
    
    // Create new hover style
    const style = document.createElement('style');
    style.id = `hover-style-${table.id}`;
    style.textContent = `
        #${table.id} tbody tr:hover {
            background-color: ${hoverColor} !important;
        }
    `;
    document.head.appendChild(style);
}

// Re-initialize when report is updated
function reinitializeTableCustomization() {
    setTimeout(() => {
        addResizeHandlesToTables();
        applyAllTableSettings();
        
        // Apply column widths
        const tables = document.querySelectorAll('.table-with-controls table');
        tables.forEach(table => {
            applyColumnWidths(table);
        });
    }, 100);
}