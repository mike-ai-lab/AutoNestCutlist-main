let currentSettings = {};
let partsData = {};
let modelMaterials = []; // Not explicitly used but kept for context.
let showOnlyUsed = true; // Set to true by default as requested
let defaultCurrency = 'USD'; // Initialized from settings via Ruby later
let currentUnits = 'mm';    // Initialized from settings via Ruby later
let currentPrecision = 1;   // Initialized from settings via Ruby later
let currentAreaUnits = 'm2'; // Initialized from settings via Ruby later

// Currency exchange rates (base: USD)
// These rates are only for internal client-side display conversions if needed,
// the main currency should be handled by Ruby logic for persistence.
let exchangeRates = {
    'USD': 1.0,
    'EUR': 0.85,
    'SAR': 3.74,
    'AED': 3.67,
    'GBP': 0.79,
    'CAD': 1.25,
    'AUD': 1.35
};

// Unit conversion factors FROM unit TO mm (internal SketchUp units are always inches, but UI works in mm internally for calculation)
// Here, 1 unit means 1 mm.
const unitFactors = {
    'mm': 1,
    'cm': 10,
    'm': 1000,
    'in': 25.4,
    'ft': 304.8
};

// Area conversion factors (divisor to convert area FROM mm² TO target unit's square area)
// E.g., Area_in_Target_Unit = Area_in_mm2 / areaFactors['m2']
const areaFactors = {
    'mm2': 1,        // 1 mm² / 1 = 1 mm²
    'cm2': 100,      // 100 mm² / 100 = 1 cm²
    'm2': 1000000,   // 1,000,000 mm² / 1,000,000 = 1 m²
    'in2': 645.16,   // 645.16 mm² / 645.16 = 1 in²
    'ft2': 92903.04  // 92903.04 mm² / 92903.04 = 1 ft²
};

const currencySymbols = {
    'USD': '$', 'EUR': '€', 'GBP': '£', 'CAD': 'C$', 'AUD': 'A$',
    'JPY': '¥', 'CNY': '¥', 'INR': '₹', 'BRL': 'R$', 'MXN': '$',
    'CHF': 'CHF', 'SEK': 'kr', 'NOK': 'kr', 'DKK': 'kr', 'PLN': 'zł',
    'SAR': 'ر.س', 'AED': 'د.إ', 'KWD': 'د.ك', 'QAR': 'ر.ق', 'BHD': 'د.ب',
    'OMR': 'ر.ع', 'JOD': 'د.ا', 'LBP': 'ل.ل', 'EGP': 'ج.م', 'TND': 'د.ت',
    'MAD': 'د.م', 'DZD': 'د.ج', 'LYD': 'ل.د', 'IQD': 'د.ع', 'SYP': 'ل.س',
    'TRY': '₺', 'IRR': 'ریال'
};

// Convert value from mm to current display unit
function convertFromMM(valueInMM) {
    if (typeof valueInMM !== 'number' || isNaN(valueInMM)) return 0;
    return valueInMM / unitFactors[currentUnits];
}

// Convert value from current display unit to mm
function convertToMM(valueInDisplayUnit) {
    if (typeof valueInDisplayUnit !== 'number' || isNaN(valueInDisplayUnit)) return 0;
    return valueInDisplayUnit * unitFactors[currentUnits];
}

// Convert and format number with current precision (no unit suffix)
function formatDimension(valueInMM) {
    if (typeof valueInMM !== 'number' || isNaN(valueInMM) || valueInMM === 0) return '0'; // Return '0' for 0 values explicitly
    const converted = convertFromMM(valueInMM);
    if (currentPrecision == 0 || currentPrecision === '0' || currentPrecision === 0.0) {
        return Math.round(converted).toString();
    }
    return converted.toFixed(currentPrecision);
}

function getUnitLabel() {
    return currentUnits;
}

function getAreaUnitLabel() {
    // This is for display in headers like "Total Area (m²)"
    switch(currentAreaUnits) {
        case 'mm2': return 'mm²';
        case 'cm2': return 'cm²';
        case 'm2': return 'm²';
        case 'in2': return 'in²';
        case 'ft2': return 'ft²';
        default: return 'm²'; // Default to m² for report headers
    }
}


function receiveInitialData(data) {
    console.log('Received initial data:', data);
    currentSettings = data.settings;
    partsData = data.parts_by_material;
    window.hierarchyTree = data.hierarchy_tree || [];
    
    // Load global settings from backend
    defaultCurrency = currentSettings.default_currency || 'USD';
    currentUnits = currentSettings.units || 'mm';
    currentPrecision = currentSettings.precision !== undefined ? currentSettings.precision : 1;
    currentAreaUnits = currentSettings.area_units || 'm2'; // New: initialize area units
    
    populateSettings();
    displayPartsPreview();
    updateUnitLabels();
    
    // Update report if it exists
    if (window.currentReportData || window.g_reportData) {
        if (window.renderReport) window.renderReport();
        if (window.renderDiagrams) window.renderDiagrams();
    }

    // Ensure initial 'used only' filter is applied visually and functionally
    const foldToggleBtn = document.getElementById('foldToggle');
    if (foldToggleBtn) {
        // Force the visual state and filtering
        if (showOnlyUsed) {
            foldToggleBtn.classList.add('active');
            foldToggleBtn.querySelector('.visually-hidden').textContent = 'Show All Materials';
        } else {
            foldToggleBtn.classList.remove('active');
            foldToggleBtn.querySelector('.visually-hidden').textContent = 'Show Used Only';
        }
    }
    displayMaterials(); // Re-display materials with correct initial filter state
}

function addMaterial() {
    const materialName = `New_Material_${Date.now()}`;
    
    currentSettings.stock_materials = currentSettings.stock_materials || {};
    currentSettings.stock_materials[materialName] = {
        width: 2440,
        height: 1220,
        thickness: 18,
        price: 0,
        currency: defaultCurrency // Use global default currency
    };
    
    displayMaterials();
    callRuby('save_materials', JSON.stringify(currentSettings.stock_materials));
}

function removeMaterial(material) {
    if (confirm(`Are you sure you want to remove material "${material}"?`)) {
        delete currentSettings.stock_materials[material];
        displayMaterials();
        callRuby('save_materials', JSON.stringify(currentSettings.stock_materials));
    }
}

function updateMaterialName(input, oldName) {
    const newName = input.value.trim();
    if (newName !== oldName && newName !== '') {
        if (currentSettings.stock_materials[newName]) {
            alert(`Material with name "${newName}" already exists. Please choose a unique name.`);
            input.value = oldName; // Revert input value
            return;
        }
        currentSettings.stock_materials[newName] = currentSettings.stock_materials[oldName];
        delete currentSettings.stock_materials[oldName];
        displayMaterials(); // Re-render to update UI (especially if sorted)
        callRuby('save_materials', JSON.stringify(currentSettings.stock_materials));
    } else if (newName === '') {
        alert('Material name cannot be empty.');
        input.value = oldName;
    }
}

function updateMaterialProperty(input, material, prop) {
    if (!currentSettings.stock_materials[material]) return;

    let value = parseFloat(input.value);
    if (isNaN(value)) {
        alert(`Invalid value for ${prop}. Please enter a number.`);
        input.value = formatDimension(currentSettings.stock_materials[material][prop]); // Revert to current value
        return;
    }

    if (prop === 'price') {
        currentSettings.stock_materials[material][prop] = value;
    } else { // Dimensions (width, height, thickness) are stored in MM
        currentSettings.stock_materials[material][prop] = convertToMM(value);
    }
    
    callRuby('save_materials', JSON.stringify(currentSettings.stock_materials));
    // No need to displayMaterials, as only one field changed
}


function formatPrice(price, currency) {
    const symbol = currencySymbols[currency] || currency;
    return `${symbol}${parseFloat(price || 0).toFixed(2)}`;
}

function populateSettings() {
    const kerfInput = document.getElementById('kerf_width');
    const rotationInput = document.getElementById('allow_rotation');
    
    if (kerfInput) {
        kerfInput.value = formatDimension(currentSettings.kerf_width || 3.0);
    }
    if (rotationInput) {
        rotationInput.checked = currentSettings.allow_rotation !== false;
    }
    
    // Set global settings controls with proper checks
    // Using setTimeout to ensure DOM elements are fully available after potential re-renders
    setTimeout(() => {
        const unitsSelect = document.getElementById('settingsUnits');
        if (unitsSelect) unitsSelect.value = currentUnits;
        
        const precisionSelect = document.getElementById('settingsPrecision');
        if (precisionSelect) precisionSelect.value = currentPrecision.toString();
        
        const areaUnitsSelect = document.getElementById('settingsAreaUnits');
        if (areaUnitsSelect) areaUnitsSelect.value = currentAreaUnits;
        
        const modalCurrencySelect = document.getElementById('settingsCurrency');
        if (modalCurrencySelect) modalCurrencySelect.value = defaultCurrency;
        
        // This dropdown is now removed from main.html, so this block is technically obsolete
        // const materialListDefaultCurrencySelect = document.getElementById('defaultCurrency');
        // if (materialListDefaultCurrencySelect) materialListDefaultCurrencySelect.value = defaultCurrency;
    }, 50);
    
    // Initialize stock_materials if it doesn't exist
    if (!currentSettings.stock_materials) {
        currentSettings.stock_materials = {};
    }
    
    // Auto-load materials from detected parts
    const detectedMaterials = new Set();
    Object.keys(partsData).forEach(material => {
        detectedMaterials.add(material);
    });
    
    // Add detected materials to stock_materials if not already present with standard dimensions
    detectedMaterials.forEach(material => {
        if (!currentSettings.stock_materials[material]) {
            currentSettings.stock_materials[material] = { 
                width: 2440, 
                height: 1220, 
                thickness: 18, 
                price: 0, 
                currency: defaultCurrency 
            };
        }
    });
    
    displayMaterials();
}

function displayMaterials() {
    const container = document.getElementById('materials_list');
    container.innerHTML = '';
    
    currentSettings.stock_materials = currentSettings.stock_materials || {};
    let materials = { ...currentSettings.stock_materials }; // Create a mutable copy

    const usedMaterials = new Set();
    Object.keys(partsData).forEach(material => {
        usedMaterials.add(material);
    });
    
    // Get sort option
    const sortBy = document.getElementById('sortBy')?.value || 'alphabetical';
    
    // Create material entries with usage info
    let materialEntries = Object.keys(materials).map(material => {
        const data = materials[material];
        const isUsed = usedMaterials.has(material);
        const usageCount = isUsed ? (partsData[material]?.length || 0) : 0;
        
        return {
            name: material,
            data: data,
            isUsed: isUsed,
            usageCount: usageCount
        };
    });
    
    // Filter if showing only used OR filter out "useless" materials by default
    materialEntries = materialEntries.filter(entry => {
        const isUseless = /tomtom|default/i.test(entry.name); // Filter out "TomTom" or "Default"
        if (showOnlyUsed) {
            return entry.isUsed && !isUseless;
        }
        return !isUseless; // Always filter out useless materials, even if not 'used only'
    });
    
    // Sort materials
    if (sortBy === 'alphabetical') {
        materialEntries.sort((a, b) => a.name.localeCompare(b.name));
    } else if (sortBy === 'usage') {
        materialEntries.sort((a, b) => b.isUsed - a.isUsed || a.name.localeCompare(b.name));
    } else if (sortBy === 'mostUsed') {
        materialEntries.sort((a, b) => b.usageCount - a.usageCount || a.name.localeCompare(b.name));
    }
    
    const unitLabel = getUnitLabel();
    
    materialEntries.forEach(entry => {
        const { name: material, data, isUsed } = entry;
        let width, height, thickness, price, currency; // Currency is now just `defaultCurrency` from global state
        
        if (Array.isArray(data)) { // Legacy array format handling
            width = data[0] || 2440;
            height = data[1] || 1220;
            thickness = 18;
            price = 0;
            currency = defaultCurrency;
        } else {
            width = data.width || 2440;
            height = data.height || 1220;
            thickness = data.thickness || 18;
            price = data.price || 0;
            currency = defaultCurrency; // Always use global default currency for materials list display
        }
        
        const div = document.createElement('div');
        div.className = `material-item ${isUsed ? 'material-used' : 'material-unused'}`;
        div.innerHTML = `
            <input type="text" value="${escapeHtml(material)}" onchange="updateMaterialName(this, '${escapeHtml(material)}')">
            <input type="number" value="${formatDimension(width)}" onchange="updateMaterialProperty(this, '${escapeHtml(material)}', 'width')" placeholder="Width (${unitLabel})">
            <input type="number" value="${formatDimension(height)}" onchange="updateMaterialProperty(this, '${escapeHtml(material)}', 'height')" placeholder="Height (${unitLabel})">
            <input type="number" value="${formatDimension(thickness)}" onchange="updateMaterialProperty(this, '${escapeHtml(material)}', 'thickness')" placeholder="Thickness (${unitLabel})">
            <input type="number" value="${parseFloat(price).toFixed(currentPrecision)}" step="0.01" onchange="updateMaterialProperty(this, '${escapeHtml(material)}', 'price')" placeholder="Price per sheet">
            <div class="material-actions">
                <button class="material-action-btn" title="Remove material" onclick="removeMaterial('${escapeHtml(material)}')">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="3,6 5,6 21,6"/>
                        <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
                        <line x1="10" y1="11" x2="10" y2="17"/>
                        <line x1="14" y1="11" x2="14" y2="17"/>
                    </svg>
                </button>
                <button class="material-action-btn" title="Highlight material" onclick="highlightMaterial('${escapeHtml(material)}')">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/>
                        <circle cx="12" cy="12" r="3"/>
                    </svg>
                </button>
            </div>
            <div class="material-status">${isUsed ? `<span class="used-indicator">✓ Used</span>` : `<span class="unused-indicator">Not Used</span>`}</div>
        `;
        container.appendChild(div);
    });
    
    // Add gradient effect if folded
    if (showOnlyUsed && Object.keys(materials).length > materialEntries.length) {
        container.classList.add('folded');
    } else {
        container.classList.remove('folded');
    }
}

function displayPartsPreview() {
    const container = document.getElementById('parts_preview');
    container.innerHTML = '';
    const header = document.createElement('h3');
    header.textContent = 'Parts Found';
    container.appendChild(header);

    const unitLabel = getUnitLabel();

    Object.keys(partsData).forEach(material => {
        const parts = partsData[material] || [];
        const card = document.createElement('div');
        card.className = 'parts-card';
        const titleContainer = document.createElement('div'); // This div is the container for title + button
        titleContainer.className = 'parts-card-title'; // Apply parts-card-title style to this container
        
        const titleText = document.createElement('span'); // Span for the actual text
        titleText.textContent = `${material} (${parts.length} parts)`;
        
        const copyBtn = document.createElement('button');
        copyBtn.className = 'icon-btn'; // Now an icon-only button
        copyBtn.title = "Copy Markdown"; // Tooltip for the icon
        copyBtn.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>`;
        copyBtn.onclick = () => copyPartsPreview(material, copyBtn);
        
        titleContainer.appendChild(titleText);
        titleContainer.appendChild(copyBtn);
        card.appendChild(titleContainer); // Append the entire title container to the card

        if (parts.length === 0) {
            const empty = document.createElement('div');
            empty.className = 'parts-empty';
            empty.textContent = 'No parts for this material.';
            card.appendChild(empty);
        } else {
            const table = document.createElement('table');
            table.className = 'parts-preview-table';
            table.id = `parts-preview-${material.replace(/[^a-zA-Z0-9]/g, '_')}`;
            // Removed unit labels from headers here, as `formatDimension` returns unit-less values
            table.innerHTML = `<thead><tr><th>Name</th><th>W</th><th>H</th><th>T</th><th>Qty</th></tr></thead>`;
            const tbody = document.createElement('tbody');
            let totalQuantity = 0;
            parts.forEach(part => {
                const name = part.name || 'Unnamed Part';
                const width = formatDimension(part.width || 0);
                const height = formatDimension(part.height || 0);
                const thickness = formatDimension(part.thickness || 0);
                const quantity = part.total_quantity || part.quantity || 1;
                totalQuantity += quantity;
                const tr = document.createElement('tr');
                tr.innerHTML = `
                    <td>${escapeHtml(name)}</td>
                    <td>${width}</td>
                    <td>${height}</td>
                    <td>${thickness}</td>
                    <td>${quantity}</td>
                `;
                tbody.appendChild(tr);
            });
            // Add total row
            const totalRow = document.createElement('tr');
            totalRow.className = 'total-row';
            totalRow.innerHTML = `
                <td colspan="4" style="text-align: right; font-weight: bold;">Total</td>
                <td style="font-weight: bold;">${totalQuantity}</td>
            `;
            tbody.appendChild(totalRow);
            table.appendChild(tbody);
            card.appendChild(table);
        }

        container.appendChild(card);
    });
}

// Small HTML escape used by parts preview
function escapeHtml(str) {
    return String(str).replace(/[&<>\"']/g, function (c) {
        return {'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',"'":"&#39;"}[c];
    });
}

function processNesting() {
    // Update settings from form - convert kerf width to mm
    const kerfInput = document.getElementById('kerf_width');
    currentSettings.kerf_width = convertToMM(parseFloat(kerfInput.value));
    currentSettings.allow_rotation = document.getElementById('allow_rotation').checked;
    
    // Convert stock_materials to proper format for Ruby
    const convertedSettings = {
        kerf_width: currentSettings.kerf_width,
        allow_rotation: currentSettings.allow_rotation,
        default_currency: defaultCurrency,
        units: currentUnits,
        precision: currentPrecision,
        area_units: currentAreaUnits, // Pass area units to Ruby
        stock_materials: {} // Ruby expects this
    };
    
    Object.keys(currentSettings.stock_materials || {}).forEach(material => {
        const data = currentSettings.stock_materials[material];
        convertedSettings.stock_materials[material] = {
            width: data.width || 2440,
            height: data.height || 1220,
            thickness: data.thickness || 18, // Include thickness in the data sent
            price: data.price || 0,
            currency: defaultCurrency // Always use global default currency
        };
    });
    
    // Send to SketchUp
    callRuby('process', JSON.stringify(convertedSettings));
}

function loadDefaults() {
    callRuby('load_default_materials');
}

function importCSV() {
    callRuby('import_materials_csv');
}

function exportDatabase() {
    callRuby('export_materials_database');
}

function toggleFold() {
    showOnlyUsed = !showOnlyUsed;
    const button = document.getElementById('foldToggle');
    const visuallyHiddenSpan = button.querySelector('.visually-hidden'); // Get the span inside

    if (showOnlyUsed) {
        button.classList.add('active');
        if (visuallyHiddenSpan) visuallyHiddenSpan.textContent = 'Show All Materials';
    } else {
        button.classList.remove('active');
        if (visuallyHiddenSpan) visuallyHiddenSpan.textContent = 'Show Used Only';
    }
    displayMaterials();
}

function highlightMaterial(material) {
    callRuby('highlight_material', material);
}

function clearHighlight() {
    callRuby('clear_highlight');
}

function getCurrentSettings() {
    // Update settings from form - convert kerf width to mm
    const kerfInput = document.getElementById('kerf_width');
    currentSettings.kerf_width = convertToMM(parseFloat(kerfInput.value));
    currentSettings.allow_rotation = document.getElementById('allow_rotation').checked;
    
    // Convert stock_materials to proper format for Ruby
    const convertedSettings = {
        kerf_width: currentSettings.kerf_width,
        allow_rotation: currentSettings.allow_rotation,
        default_currency: defaultCurrency, // Include default currency
        units: currentUnits, // Include units
        precision: currentPrecision, // Include precision
        area_units: currentAreaUnits, // Include area units
        stock_materials: {}
    };
    
    Object.keys(currentSettings.stock_materials || {}).forEach(material => {
        const data = currentSettings.stock_materials[material];
        convertedSettings.stock_materials[material] = {
            width: data.width || 2440,
            height: data.height || 1220,
            thickness: data.thickness || 18, // Include thickness
            price: data.price || 0,
            currency: defaultCurrency // Always use global default currency
        };
    });
    
    return convertedSettings;
}

function callRuby(method, args) {
    if (typeof sketchup === 'object' && sketchup[method]) {
        sketchup[method](args);
    } else {
        // Debug logging removed for production, but can be re-enabled for dev
        console.warn(`Ruby method '${method}' not found or sketchup object not available.`);
    }
}

// Resizer functionality
let resizerInitialized = false;

function initResizer() {
    if (resizerInitialized) return;
    
    const resizer = document.getElementById('resizer');
    const leftSide = document.getElementById('diagramsContainer');
    const rightSide = document.getElementById('reportContainer');
    
    if (!resizer || !leftSide || !rightSide) return;
    
    let isResizing = false;
    
    resizer.addEventListener('mousedown', (e) => {
        isResizing = true;
        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none';
    });
    
    document.addEventListener('mousemove', (e) => {
        if (!isResizing) return;
        
        const container = document.querySelector('.container');
        const containerRect = container.getBoundingClientRect();
        const newLeftWidth = e.clientX - containerRect.left;
        const totalWidth = containerRect.width;
        
        if (newLeftWidth > 300 && totalWidth - newLeftWidth > 400) {
            leftSide.style.flex = `0 0 ${newLeftWidth}px`;
            rightSide.style.flex = `1 1 auto`;
        }
    });
    
    document.addEventListener('mouseup', () => {
        if (isResizing) {
            isResizing = false;
            document.body.style.cursor = '';
            document.body.style.userSelect = '';
        }
    });
    
    resizerInitialized = true;
}

function updateUnits() {
    const select = document.getElementById('settingsUnits');
    if (!select) return;
    
    currentUnits = select.value;
    
    // Update backend setting immediately
    callRuby('update_global_setting', JSON.stringify({key: 'units', value: currentUnits}));
    // localStorage.setItem('autoNestCutUnits', currentUnits); // Remove localStorage, use Ruby for persistence
    
    updateUnitLabels();
    displayMaterials();
    displayPartsPreview();
    
    if (typeof renderReport === 'function' && typeof renderDiagrams === 'function') {
        renderReport();
        renderDiagrams();
    }
}

function updatePrecision() {
    const select = document.getElementById('settingsPrecision');
    if (!select) return;
    
    currentPrecision = parseInt(select.value);
    
    // Update backend setting immediately
    callRuby('update_global_setting', JSON.stringify({key: 'precision', value: currentPrecision}));
    // localStorage.setItem('autoNestCutPrecision', currentPrecision); // Remove localStorage, use Ruby for persistence
    
    displayMaterials();
    displayPartsPreview();
    
    if (typeof renderReport === 'function' && typeof renderDiagrams === 'function') {
        renderReport();
        renderDiagrams();
    }
}

function openSettings() {
    const modal = document.getElementById('settingsModal');
    if (modal) {
        modal.style.display = 'block';
        
        const unitsSelect = document.getElementById('settingsUnits');
        const precisionSelect = document.getElementById('settingsPrecision');
        const currencySelect = document.getElementById('settingsCurrency');
        const areaUnitsSelect = document.getElementById('settingsAreaUnits');
        
        if (unitsSelect) unitsSelect.value = currentUnits;
        if (precisionSelect) precisionSelect.value = currentPrecision.toString();
        if (areaUnitsSelect) areaUnitsSelect.value = currentAreaUnits;
        if (currencySelect) currencySelect.value = defaultCurrency;
        
        // Allow clicking outside to close
        modal.onclick = (e) => {
            if (e.target === modal) closeSettings();
        };
    }
}

function closeSettings() {
    const modal = document.getElementById('settingsModal');
    if (modal) {
        modal.style.display = 'none';
        modal.onclick = null; // Remove event listener to prevent memory leaks
    }
}

// These functions for exchange rates are no longer tied to main UI currency management
// and are effectively for a future feature or separate logic if needed.
function updateExchangeRate() {
    // ... (existing logic, not directly used in main currency flow)
}
function convertReportCurrency() {
    // ... (existing logic, not directly used in main currency flow)
}

function updateAreaUnits() {
    const select = document.getElementById('settingsAreaUnits');
    if (!select) return;
    
    currentAreaUnits = select.value;
    
    // Update backend setting immediately
    callRuby('update_global_setting', JSON.stringify({key: 'area_units', value: currentAreaUnits}));
    // localStorage.setItem('autoNestCutAreaUnits', currentAreaUnits); // Remove localStorage, use Ruby for persistence
    
    // Update report if it exists
    if (typeof renderReport === 'function') {
        renderReport();
    }
}

function updateCurrency() {
    const select = document.getElementById('settingsCurrency');
    if (!select) return;
    
    defaultCurrency = select.value;
    
    // Update backend setting immediately
    callRuby('update_global_setting', JSON.stringify({key: 'default_currency', value: defaultCurrency}));
    
    // Update current materials to use the new default currency
    Object.keys(currentSettings.stock_materials || {}).forEach(material => {
        const data = currentSettings.stock_materials[material];
        data.currency = defaultCurrency; // Explicitly update material's currency
    });
    callRuby('save_materials', JSON.stringify(currentSettings.stock_materials)); // Save updated materials list
    
    displayMaterials(); // Re-render materials list to reflect currency changes (though column is gone)
    
    // Update report if it exists
    if (typeof renderReport === 'function') {
        renderReport();
    }
}


function updateUnitLabels() {
    const unitText = currentUnits;
    
    // Update data-translate elements
    document.querySelectorAll('[data-translate="width_mm"]').forEach(el => {
        el.textContent = `Width (${unitText})`;
    });
    document.querySelectorAll('[data-translate="height_mm"]').forEach(el => {
        el.textContent = `Height (${unitText})`;
    });
    document.querySelectorAll('[data-translate="thickness_mm"]').forEach(el => {
        el.textContent = `Thickness (${unitText})`;
    });
    
    // Update kerf width label
    const kerfLabel = document.querySelector('label[for="kerf_width"]');
    if (kerfLabel) {
        kerfLabel.textContent = `Kerf Width (${unitText}):`;
    }
    
    // Update any other unit labels in the interface (e.g., in parts preview headers)
    document.querySelectorAll('.parts-preview-table thead th').forEach(el => {
        const text = el.textContent;
        if (text === 'W' || text === 'H' || text === 'T') {
            el.textContent = `${text} (${unitText})`;
        }
    });

    // Update parts preview table headers if they include W, H, T
    document.querySelectorAll('.parts-preview-table thead th').forEach(th => {
        const originalText = th.dataset.originalText || th.textContent;
        th.dataset.originalText = originalText; // Store original text
        if (originalText.startsWith('W (') || originalText.startsWith('H (') || originalText.startsWith('T (')) {
            // Skip, as these were formatted by default, or handle later if more complex
        } else if (originalText === 'W' || originalText === 'H' || originalText === 'T') {
            th.textContent = `${originalText} (${unitText})`;
        }
    });
}

function copyPartsPreview(material, button) {
    const tableId = `parts-preview-${material.replace(/[^a-zA-Z0-9]/g, '_')}`;
    const table = document.getElementById(tableId);
    if (!table) return;
    
    let markdown = `## ${material}\n\n`;
    const rows = table.querySelectorAll('tr');
    
    rows.forEach((row, index) => {
        const cells = row.querySelectorAll('th, td');
        const rowData = Array.from(cells).map(cell => cell.textContent.trim()).join(' | ');
        markdown += '| ' + rowData + ' |\n';
        
        if (index === 0) {
            const separator = Array.from(cells).map(() => '---').join(' | ');
            markdown += '| ' + separator + ' |\n';
        }
    });
    
    navigator.clipboard.writeText(markdown).then(() => {
        button.classList.add('copied');
        const originalText = button.innerHTML;
        button.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20,6 9,17 4,12"/></svg>`;
        
        setTimeout(() => {
            button.classList.remove('copied');
            button.innerHTML = originalText;
        }, 2000);
    });
}

// Initialize when page loads
window.addEventListener('load', function() {
    // Initial calls for settings, these values will be overwritten by Ruby's receiveInitialData
    // but ensure defaults are set before Ruby responds.
    currentUnits = 'mm';
    currentPrecision = 1;
    currentAreaUnits = 'm2';
    defaultCurrency = 'USD';
    
    callRuby('ready');
    setTimeout(initResizer, 100);

    // Initial state for 'show only used' filter button
    const foldToggleBtn = document.getElementById('foldToggle');
    if (foldToggleBtn) {
        if (showOnlyUsed) {
            foldToggleBtn.classList.add('active');
            const visuallyHiddenSpan = document.createElement('span');
            visuallyHiddenSpan.className = 'visually-hidden';
            visuallyHiddenSpan.textContent = 'Show All Materials';
            foldToggleBtn.appendChild(visuallyHiddenSpan);
        } else {
            const visuallyHiddenSpan = document.createElement('span');
            visuallyHiddenSpan.className = 'visually-hidden';
            visuallyHiddenSpan.textContent = 'Show Used Only';
            foldToggleBtn.appendChild(visuallyHiddenSpan);
        }
    }
});
