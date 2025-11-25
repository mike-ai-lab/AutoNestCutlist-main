// Global formatting utility - put this at the top of the script or in a global utility file.
// This ensures consistency across all numeric displays affected by precision settings.

// Ensure window.currencySymbols and other globals are defined if app.js hasn't done so
// This prevents "Cannot read properties of undefined" errors if app.js loads later or fails.
window.currencySymbols = window.currencySymbols || {
    'USD': '$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CAD': '$',
    'AUD': '$',
    'CHF': 'CHF',
    'CNY': '¥',
    'SEK': 'kr',
    'NZD': '$',
    'SAR': 'SAR', // Added SAR
    // Add other common currencies as needed
};

// Also ensure other critical globals expected from app.js are initialized
window.currentUnits = window.currentUnits || 'mm';
window.currentPrecision = window.currentPrecision ?? 1; // Use nullish coalescing for precision
window.currentAreaUnits = window.currentAreaUnits || 'm2'; // Ensure this is also global
window.areaFactors = window.areaFactors || {
    'mm2': 1,
    'cm2': 100,
    'm2': 1000000,
    'in2': 645.16, // Factor for converting from mm² to in² (1 in² = 645.16 mm²)
    'ft2': 92903.04, // Factor for converting from mm² to ft² (1 ft² = 92903.04 mm²)
};
window.unitFactors = window.unitFactors || { // Unit factors for linear dimensions (mm as base)
    'mm': 1,
    'cm': 10,
    'm': 1000,
    'in': 25.4,
    'ft': 304.8
};
window.defaultCurrency = window.defaultCurrency || 'USD';


function getAreaDisplay(areaMM2) {
    // Using currentAreaUnits and areaFactors from app.js globals
    const units = window.currentAreaUnits || 'm2';
    // The factor needs to divide areaMM2 to convert to target area unit.
    // e.g., if areaMM2 is 1,000,000 and units is 'm2', factor is 1,000,000. 1,000,000 / 1,000,000 = 1 m2
    const factor = window.areaFactors[units] || window.areaFactors['m2']; // Fallback to m2 factor
    const convertedArea = areaMM2 / factor;
    // Return formatted number only, unit is in the header
    return formatNumber(convertedArea, window.currentPrecision); 
}

function formatAreaForPDF(areaMM2) {
    const units = window.currentAreaUnits || 'm2';
    const areaLabels = { mm2: 'mm²', cm2: 'cm²', m2: 'm²', in2: 'in²', ft2: 'ft²' };
    const factor = window.areaFactors[units] || window.areaFactors['m2']; 
    const convertedArea = areaMM2 / factor;
    return `${formatNumber(convertedArea, window.currentPrecision)} ${areaLabels[units]}`;
}

function getAreaUnitLabel() {
    // This function can be more complex if you have specific labels for units.
    // For now, it will just return 'm2', 'mm2', etc.
    // It should ideally return a displayable string like 'm²'
    const unitMap = {
        'mm2': 'mm²',
        'cm2': 'cm²',
        'm2': 'm²',
        'in2': 'in²',
        'ft2': 'ft²'
    };
    return unitMap[window.currentAreaUnits] || window.currentAreaUnits || 'm²';
}


function formatNumber(value, precision) {
    if (typeof value !== 'number' || isNaN(value) || value === null) { // Handle null, undefined, NaN
        return '-'; // Return placeholder for invalid numbers
    }
    
    // Explicitly check for 0 or string '0' to use Math.round for no decimal places.
    // This correctly renders 800 instead of 800.0 when precision is 0.
    const actualPrecision = (precision === 0 || precision === '0' || precision === 0.0) ? 0 : (typeof precision === 'number' ? precision : parseFloat(precision));
    
    if (isNaN(actualPrecision) || actualPrecision < 0) {
        console.warn('Invalid precision provided to formatNumber, defaulting to 1 decimal:', precision);
        return value.toFixed(1); // Default to 1 decimal place if precision is invalid
    }
    
    return value.toFixed(actualPrecision);
}

function callRuby(method, args) {
    if (typeof sketchup === 'object' && sketchup[method]) {
        console.log(`Calling Ruby method: ${method} with args:`, args);
        sketchup[method](args);
    } else {
        console.warn(`Ruby method '${method}' not found or sketchup object not available.`);
    }
}

let g_boardsData = [];
let g_reportData = null;
let currentHighlightedPiece = null;
let currentHighlightedCanvas = null;


function receiveData(data) {
    console.log('receiveData called with data:', data);
    g_boardsData = data.diagrams;
    g_reportData = data.report;
    window.originalComponents = data.original_components || [];
    window.hierarchyTree = data.hierarchy_tree || [];
    
    // Update global settings from the received report data for consistency
    if (g_reportData && g_reportData.summary) {
        window.currentUnits = g_reportData.summary.units || 'mm';
        window.currentPrecision = g_reportData.summary.precision ?? 1;
        window.defaultCurrency = g_reportData.summary.currency || 'USD';
        window.currentAreaUnits = g_reportData.summary.area_units || 'm2';
    }

    renderDiagrams();
    renderReport();
}

function convertDimension(value, fromUnit, toUnit) {
    if (fromUnit === toUnit) return value;
    const valueInMM = value * window.unitFactors[fromUnit];
    return valueInMM / window.unitFactors[toUnit];
}

function renderDiagrams() {
    console.log('renderDiagrams called, g_boardsData:', g_boardsData);
    
    const container = document.getElementById('diagramsContainer');
    if (!container) {
        console.error('diagramsContainer element not found');
        return;
    }
    
    container.innerHTML = '';

    if (!g_boardsData || g_boardsData.length === 0) {
        console.log('No boards data available');
        container.innerHTML = '<p>No cutting diagrams to display. Please generate a cut list first.</p>';
        return;
    }
    
    console.log('Rendering', g_boardsData.length, 'diagrams');

    // Use report-specific units and precision
    const reportUnits = window.currentUnits || 'mm';
    const reportPrecision = window.currentPrecision ?? 1; 

    g_boardsData.forEach((board, boardIndex) => {
        console.log('Rendering board', boardIndex, ':', board);
        const card = document.createElement('div');
        card.className = 'diagram-card';

        const title = document.createElement('h3');
        title.textContent = `${board.material} Board ${boardIndex + 1}`;
        title.id = `diagram-${board.material.replace(/[^a-zA-Z0-9]/g, '_')}-${boardIndex}`;
        card.appendChild(title);

        const info = document.createElement('p');
        // Use global `currentUnits` and `currentPrecision` from app.js
        
        const width = board.stock_width / window.unitFactors[reportUnits];
        const height = board.stock_height / window.unitFactors[reportUnits];
        
        // Removed `units` from dimension values in info string
        info.innerHTML = `Size: ${formatNumber(width, reportPrecision)}×${formatNumber(height, reportPrecision)} ${reportUnits}<br>
                          Waste: ${formatNumber(board.waste_percentage, 1)}% (Efficiency: ${formatNumber(board.efficiency_percentage, 1)}%)`;
        card.appendChild(info);

        const canvas = document.createElement('canvas');
        canvas.className = 'diagram-canvas';
        card.appendChild(canvas);

        container.appendChild(card);

        // Define drawCanvas as a method on the canvas object itself or a helper
        // to simplify redrawing and maintain scope.
        canvas.drawCanvas = function() { // Bind drawing function to canvas
            const containerWidth = card.offsetWidth - 24;
            const ctx = canvas.getContext('2d');
            const padding = 40;
            const maxCanvasDim = Math.min(containerWidth, 600);
            
            const boardWidth = parseFloat(board.stock_width) || 1000;
            const boardHeight = parseFloat(board.stock_height) || 1000;
            
            const scale = Math.min(
                (maxCanvasDim - 2 * padding) / boardWidth,
                (maxCanvasDim - 2 * padding) / boardHeight
            );

            canvas.width = boardWidth * scale + 2 * padding;
            canvas.height = boardHeight * scale + 2 * padding;

            ctx.fillStyle = '#f5f5f5';
            ctx.fillRect(padding, padding, boardWidth * scale, boardHeight * scale);
            ctx.strokeStyle = '#666';
            ctx.lineWidth = 2;
            ctx.strokeRect(padding, padding, boardWidth * scale, boardHeight * scale);
            
            ctx.fillStyle = '#333';
            ctx.font = `${Math.max(12, 14 * scale)}px Arial`;
            ctx.textAlign = 'center';
            const displayWidth = boardWidth / window.unitFactors[reportUnits];
            // FIX: Use formatNumber for canvas board dimensions for consistency
            ctx.fillText(`${formatNumber(displayWidth, reportPrecision)}${reportUnits}`, padding + (boardWidth * scale) / 2, padding - 5);
            
            ctx.save();
            ctx.translate(padding - 15, padding + (boardHeight * scale) / 2);
            ctx.rotate(-Math.PI / 2);
            const displayHeight = boardHeight / window.unitFactors[reportUnits];
            // FIX: Use formatNumber for canvas board dimensions for consistency
            ctx.fillText(`${formatNumber(displayHeight, reportPrecision)}${reportUnits}`, 0, 0);
            ctx.restore();

            const parts = board.parts || [];
            console.log('Board', boardIndex, 'has', parts.length, 'parts');
            canvas.boardIndex = boardIndex;
            canvas.boardData = board;
            canvas.partData = [];
            
            parts.forEach((part, partIndex) => {
                console.log('Rendering part', partIndex, ':', part);
                // Ensure part dimensions and positions are valid numbers
                const partPosX = parseFloat(part.x) || 0;
                const partPosY = parseFloat(part.y) || 0;
                const partW = parseFloat(part.width) || 10;
                const partH = parseFloat(part.height) || 10;
                
                const partX = padding + partPosX * scale;
                const partY = padding + partPosY * scale;
                const partWidth = partW * scale;
                const partHeight = partH * scale;

                // Draw base color with grain pattern
                drawPartWithGrain(ctx, partX, partY, partWidth, partHeight, part);
                
                ctx.strokeStyle = '#333';
                ctx.lineWidth = 0.5;
                ctx.strokeRect(partX, partY, partWidth, partHeight);
                
                // Draw edge banding indicators
                if (part.edge_banding && part.edge_banding !== 'None') {
                    ctx.strokeStyle = '#ff6b35';
                    ctx.lineWidth = 3;
                    
                    if (part.edge_banding.includes('All') || part.edge_banding === '4 edges') {
                        ctx.strokeRect(partX, partY, partWidth, partHeight);
                    } else if (part.edge_banding.includes('2 edges')) {
                        ctx.beginPath();
                        ctx.moveTo(partX, partY);
                        ctx.lineTo(partX + partWidth, partY);
                        ctx.moveTo(partX, partY + partHeight);
                        ctx.lineTo(partX + partWidth, partY + partHeight);
                        ctx.stroke();
                    } else if (part.edge_banding.includes('1 edge')) {
                        ctx.beginPath();
                        ctx.moveTo(partX, partY);
                        ctx.lineTo(partX + partWidth, partY);
                        ctx.stroke();
                    }
                }
                
                // Draw grain direction arrow
                drawGrainArrow(ctx, partX, partY, partWidth, partHeight, part.grain_direction);

                canvas.partData.push({
                    x: partX, y: partY, width: partWidth, height: partHeight,
                    part: part, boardIndex: boardIndex
                });

                // Width dimension - always at top edge
                if (partWidth > 50) {
                    ctx.fillStyle = '#000000';
                    ctx.font = `${Math.max(11, 12 * scale)}px Arial`;
                    ctx.textAlign = 'center';
                    ctx.textBaseline = 'top';
                    const partDisplayW = partW / window.unitFactors[reportUnits];
                    ctx.fillText(`${formatNumber(partDisplayW, reportPrecision)}`, partX + partWidth / 2, partY + 5); // Removed unit
                }

                // Height dimension - always at left edge
                if (partHeight > 50) {
                    ctx.save();
                    ctx.translate(partX + 5, partY + partHeight / 2);
                    ctx.rotate(-Math.PI / 2);
                    ctx.fillStyle = '#000000';
                    ctx.font = `${Math.max(11, 12 * scale)}px Arial`;
                    ctx.textAlign = 'center';
                    ctx.textBaseline = 'top';
                    const partDisplayH = partH / window.unitFactors[reportUnits];
                    ctx.fillText(`${formatNumber(partDisplayH, reportPrecision)}`, 0, 0); // Removed unit
                    ctx.restore();
                }

                // Label - adjust position to avoid dimension overlap
                if (partWidth > 30 && partHeight > 20) {
                    ctx.fillStyle = '#000000';
                    ctx.font = `bold ${Math.max(14, 16 * scale)}px Arial`;
                    ctx.textAlign = 'center';
                    ctx.textBaseline = 'middle';
                    const labelContent = String(part.instance_id || `P${partIndex + 1}`);
                    const maxChars = Math.max(6, Math.floor(partWidth / 8));
                    const displayLabel = labelContent.length > maxChars ? labelContent.slice(0, maxChars - 1) + '…' : labelContent;
                    
                    let labelX = partX + partWidth / 2;
                    let labelY = partY + partHeight / 2;
                    
                    // For very tall narrow pieces, move label down along height
                    if (partWidth < 50 && partHeight > partWidth * 2) {
                        labelY = partY + partHeight * 0.7; // Move down along tall dimension
                    }
                    
                    // For very short wide pieces, move label right along width  
                    if (partHeight < 35 && partWidth > partHeight * 2) {
                        labelX = partX + partWidth * 0.7; // Move right along wide dimension
                    }
                    
                    ctx.fillText(displayLabel, labelX, labelY);
                }
            });

            canvas.addEventListener('click', (e) => handleCanvasClick(e, canvas));
            canvas.addEventListener('mousemove', (e) => handleCanvasHover(e, canvas));
            canvas.style.cursor = 'pointer';
        };
        
        canvas.drawCanvas(); // Initial draw
        
        const resizeObserver = new ResizeObserver(() => {
            canvas.drawCanvas(); // Redraw on resize
        });
        resizeObserver.observe(card);
    });
    
    console.log('Finished rendering diagrams');
}

function renderReport() {
    console.log('renderReport called, g_reportData:', g_reportData);
    
    if (!g_reportData) {
        console.error('No report data available');
        return;
    }
    
    // Validate report data structure
    if (!g_reportData.summary) {
        console.error('Report data missing summary section');
        const container = document.getElementById('reportContainer');
        if (container) {
            container.innerHTML = '<div style="color: red; padding: 20px; text-align: center;"><h3>Invalid Report Data</h3><p>The report data is incomplete. Please try generating the cut list again.</p></div>';
        }
        return;
    }

    console.log('Report summary:', g_reportData.summary);
    // Use globals from app.js
    const currency = g_reportData.summary.currency || window.defaultCurrency || 'USD';
    const reportUnits = window.currentUnits || 'mm';
    const reportPrecision = window.currentPrecision ?? 1; 
    const currencySymbol = window.currencySymbols[currency] || currency;
    const currentAreaUnitLabel = getAreaUnitLabel(); // Get label like 'm²'


    const summaryTable = document.getElementById('summaryTable');
    if (summaryTable) {
        console.log('Rendering summary table');
        summaryTable.innerHTML = `
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Total Parts Instances</td><td>${g_reportData.summary.total_parts_instances || 0}</td></tr>
            <tr><td>Total Unique Part Types</td><td>${g_reportData.summary.total_unique_part_types || 0}</td></tr>
            <tr><td>Total Boards</td><td>${g_reportData.summary.total_boards || 0}</td></tr>
            <tr><td>Overall Efficiency</td><td>${formatNumber(g_reportData.summary.overall_efficiency || 0, reportPrecision)}%</td></tr>
            <tr><td><strong>Total Project Cost</strong></td><td class="total-highlight"><strong>${currencySymbol}${formatNumber(g_reportData.summary.total_project_cost || 0, 2)}</strong></td></tr>
        `;
    } else {
        console.error('summaryTable element not found');
    }

    const materialsUsedTable = document.getElementById('materialsUsedTable');
    if (materialsUsedTable && g_reportData.unique_board_types) {
        materialsUsedTable.innerHTML = `<tr><th>Material</th><th>Price per Sheet</th></tr>`;
        g_reportData.unique_board_types.forEach(board_type => {
            const boardCurrency = board_type.currency || currency;
            const boardSymbol = window.currencySymbols[boardCurrency] || boardCurrency;
            materialsUsedTable.innerHTML += `<tr><td>${board_type.material}</td><td>${boardSymbol}${formatNumber(board_type.price_per_sheet || 0, 2)}</td></tr>`;
        });
    } else if (materialsUsedTable) { // If table exists but no data, clear it.
        materialsUsedTable.innerHTML = `<tr><th>Material</th><th>Price per Sheet</th></tr><tr><td colspan="2">No materials data available.</td></tr>`;
    }


    const uniquePartTypesTable = document.getElementById('uniquePartTypesTable');
    if (uniquePartTypesTable) {
        console.log('Rendering unique part types table');
        // Updated header for Total Area to include unit
        let html = `<thead><tr><th>Name</th><th>W (${reportUnits})</th><th>H (${reportUnits})</th><th>Thick (${reportUnits})</th><th>Material</th><th>Grain</th><th>Edge Banding</th><th>Total Qty</th><th style="text-align:right;">Total Area (${currentAreaUnitLabel})</th></tr></thead><tbody>`;
        if (g_reportData.unique_part_types && g_reportData.unique_part_types.length > 0) {
            console.log('Found', g_reportData.unique_part_types.length, 'unique part types');
            g_reportData.unique_part_types.forEach(part_type => {
                const width = part_type.width / window.unitFactors[reportUnits];
                const height = part_type.height / window.unitFactors[reportUnits];
                const thickness = part_type.thickness / window.unitFactors[reportUnits];
                
                // Use the global formatNumber function
                html += `
                    <tr>
                        <td title="${part_type.name}">${part_type.name}</td>
                        <td>${formatNumber(width, reportPrecision)}</td>
                        <td>${formatNumber(height, reportPrecision)}</td>
                        <td>${formatNumber(thickness, reportPrecision)}</td>
                        <td title="${part_type.material}">${part_type.material}</td>
                        <td>${part_type.grain_direction}</td>
                        <td>${part_type.edge_banding || 'None'}</td>
                        <td class="total-highlight">${part_type.total_quantity}</td>
                        <td style="text-align:right;">${getAreaDisplay(part_type.total_area)}</td>
                    </tr>
                `;
            });
        }
        html += `</tbody>`;
        uniquePartTypesTable.innerHTML = html;
    } else {
        console.error('uniquePartTypesTable element not found');
    }

    // Sheet Inventory Summary Table
    const sheetInventoryTable = document.getElementById('sheetInventoryTable');
    if (sheetInventoryTable && g_reportData.unique_board_types) {
        // Updated Dimensions header to explicitly include units
        let html = `<thead><tr><th>Material</th><th>Dimensions (${reportUnits})</th><th>Count</th><th style="text-align:right;">Total Area (${currentAreaUnitLabel})</th><th>Price/Sheet</th><th>Total Cost</th></tr></thead><tbody>`;
        g_reportData.unique_board_types.forEach(board_type => {
            const boardCurrency = board_type.currency || currency;
            const boardSymbol = window.currencySymbols[boardCurrency] || boardCurrency;
            const width_mm = parseFloat(board_type.stock_width);
            const height_mm = parseFloat(board_type.stock_height);

            const width = width_mm / window.unitFactors[reportUnits];
            const height = height_mm / window.unitFactors[reportUnits];
            // Removed unit from dimensionsStr
            const dimensionsStr = `${formatNumber(width, reportPrecision)} × ${formatNumber(height, reportPrecision)}`;
            
            html += `
                <tr>
                    <td title="${board_type.material}">${board_type.material}</td>
                    <td>${dimensionsStr}</td>
                    <td class="total-highlight">${board_type.count}</td>
                    <td style="text-align:right;">${getAreaDisplay(board_type.total_area)}</td>
                    <td>${boardSymbol}${formatNumber(board_type.price_per_sheet || 0, 2)}</td>
                    <td class="total-highlight">${boardSymbol}${formatNumber(board_type.total_cost || 0, 2)}</td>
                </tr>
            `;
        });
        html += `</tbody>`;
        sheetInventoryTable.innerHTML = html;
    }

    const partsTable = document.getElementById('partsTable');
    if (partsTable) {
        console.log('Rendering parts table');
        
        // Calculate piece costs and statistics (logic from original)
        const parts_list = g_reportData.parts_placed || g_reportData.parts || [];
        const boardTypeMap = {};
        g_reportData.unique_board_types.forEach(bt => {
            boardTypeMap[bt.material] = {
                price: bt.price_per_sheet || 0,
                currency: bt.currency || currency,
                area: (bt.stock_width || 2440) * (bt.stock_height || 1220) // Use actual stock_width/height from board_type
            };
        });
        
        const partsWithCosts = parts_list.map(part => {
            const boardType = boardTypeMap[part.material] || { price: 0, currency: currency, area: 2976800 }; // Fallback to default area
            const partArea = (part.width || 0) * (part.height || 0); // in mm²
            const costPerMm2 = boardType.area > 0 ? boardType.price / boardType.area : 0;
            const partCost = partArea * costPerMm2;
            return { ...part, cost: partCost, currency: boardType.currency };
        });
        
        const costs = partsWithCosts.map(p => p.cost).filter(c => c > 0);
        const totalPartsCost = costs.reduce((a, b) => a + b, 0);
        const avgCost = costs.length > 0 ? totalPartsCost / costs.length : 0;
        
        let partsHtml = `<thead><tr><th>ID</th><th>Name</th><th>Dimensions (${reportUnits})</th><th>Material</th><th>Grain</th><th>Edge Banding</th><th>Board#</th><th>Cost</th><th>Level</th></tr></thead><tbody>`;
        
        partsWithCosts.forEach(part => {
            const partId = part.part_unique_id || part.part_number;
            const width = (part.width || 0) / window.unitFactors[reportUnits];
            const height = (part.height || 0) / window.unitFactors[reportUnits];
            // Removed unit from dimensionsStr
            const dimensionsStr = `${formatNumber(width, reportPrecision)} × ${formatNumber(height, reportPrecision)}`;
            const partSymbol = window.currencySymbols[part.currency] || part.currency;
            
            let costLevel = 'avg', costColor = '#ffa500', costText = 'Average';
            if (part.cost > avgCost * 1.2) { costLevel = 'high'; costColor = '#ff4444'; costText = 'High'; }
            else if (part.cost < avgCost * 0.8 && part.cost > 0) { costLevel = 'low'; costColor = '#44aa44'; costText = 'Low'; }
            
            partsHtml += `
                <tr data-part-id="${partId}" data-board-number="${part.board_number}" data-cost-level="${costLevel}">
                    <td><button class="part-id-btn" onclick="scrollToPieceDiagram('${partId}', ${part.board_number})">${partId}</button></td>
                    <td title="${part.name}">${part.name}</td>
                    <td>${dimensionsStr}</td>
                    <td title="${part.material}">${part.material}</td>
                    <td>${part.grain_direction || 'Any'}</td>
                    <td>${part.edge_banding || 'None'}</td>
                    <td>${part.board_number}</td>
                    <td>${partSymbol}${formatNumber(part.cost, 2)}</td>
                    <td><span class="cost-indicator" style="background: ${costColor}; color: white; padding: 2px 6px; border-radius: 3px; font-size: 11px;">${costText}</span></td>
                </tr>
            `;
        });
        
        partsHtml += `
                <tr style="border-top: 2px solid #22863a; background: #f6ffed;">
                    <td colspan="7" style="text-align: right; font-weight: bold;">Total Parts Cost:</td>
                    <td style="font-weight: bold; color: #22863a;">${currencySymbol}${formatNumber(totalPartsCost, 2)}</td>
                    <td></td>
                </tr>
            </tbody>`;
        
        partsTable.innerHTML = partsHtml;
        // attachPartTableClickHandlers(); // This function is empty, no need to call
    } else {
        console.error('partsTable element not found');
    }
    
    console.log('Finished rendering report');
}

function getMaterialColor(material) {
    let hash = 0;
    for (let i = 0; i < material.length; i++) {
        hash = material.charCodeAt(i) + ((hash << 5) - hash);
    }
    const hue = Math.abs(hash) % 360;
    return `hsl(${hue}, 60%, 80%)`;
}

function drawPartWithGrain(ctx, x, y, width, height, part) {
    const baseColor = getMaterialColor(part.material);
    ctx.fillStyle = baseColor;
    ctx.fillRect(x, y, width, height);
    
    // Add grain pattern overlay
    if (part.grain_direction && part.grain_direction !== 'Any') {
        ctx.save();
        ctx.globalAlpha = 0.3;
        ctx.strokeStyle = '#8B4513';
        ctx.lineWidth = 1;
        
        const spacing = 8;
        if (part.grain_direction === 'L' || part.grain_direction === 'length') {
            // Vertical grain lines
            for (let i = x; i < x + width; i += spacing) {
                ctx.beginPath();
                ctx.moveTo(i, y);
                ctx.lineTo(i, y + height);
                ctx.stroke();
            }
        } else if (part.grain_direction === 'W' || part.grain_direction === 'width') {
            // Horizontal grain lines
            for (let i = y; i < y + height; i += spacing) {
                ctx.beginPath();
                ctx.moveTo(x, i);
                ctx.lineTo(x + width, i);
                ctx.lineTo(x + width, i); // Ensure proper line path
                ctx.stroke();
            }
        }
        ctx.restore();
    }
}

function drawGrainArrow(ctx, x, y, width, height, grainDirection) {
    if (!grainDirection || grainDirection === 'Any') return;
    
    ctx.save();
    ctx.strokeStyle = '#2c3e50';
    ctx.fillStyle = '#2c3e50';
    ctx.lineWidth = 2;
    
    const centerX = x + width / 2;
    const arrowSize = Math.min(width, height) * 0.15;
    
    if (grainDirection === 'L' || grainDirection === 'length') {
        // Vertical arrow at top
        const arrowY = y + 20;
        const arrowEndY = arrowY + Math.max(arrowSize, 20);
        
        // Arrow line
        ctx.beginPath();
        ctx.moveTo(centerX, arrowY);
        ctx.lineTo(centerX, arrowEndY);
        ctx.stroke();
        
        // Arrow head (triangle)
        ctx.beginPath();
        ctx.moveTo(centerX, arrowY);
        ctx.lineTo(centerX - 4, arrowY + 8);
        ctx.lineTo(centerX + 4, arrowY + 8);
        ctx.closePath();
        ctx.fill();
    } else if (grainDirection === 'W' || grainDirection === 'width') {
        // Horizontal arrow at bottom
        const arrowY = y + height - 20;
        const arrowStartX = centerX - Math.max(arrowSize/2, 15);
        const arrowEndX = centerX + Math.max(arrowSize/2, 15);
        
        // Arrow line
        ctx.beginPath();
        ctx.moveTo(arrowStartX, arrowY);
        ctx.lineTo(arrowEndX, arrowY);
        ctx.stroke();
        
        // Arrow head (triangle)
        ctx.beginPath();
        ctx.moveTo(arrowEndX, arrowY);
        ctx.lineTo(arrowEndX - 8, arrowY - 4);
        ctx.lineTo(arrowEndX - 8, arrowY + 4);
        ctx.closePath();
        ctx.fill();
    }
    
    ctx.restore();
}

// Function to redraw a specific canvas diagram
function redrawCanvasDiagram(canvas, board) {
    if (canvas.drawCanvas) {
        canvas.drawCanvas(); // Call the drawing function bound to the canvas
    }
}

function getMaterialTexture(material) {
    if (material.toLowerCase().includes('wood') || material.toLowerCase().includes('chestnut')) {
        return 'repeating-linear-gradient(45deg, #8B4513, #8B4513 2px, #A0522D 2px, #A0522D 4px)';
    } else if (material.includes('240,240,240')) {
        return 'repeating-linear-gradient(90deg, #f0f0f0, #f0f0f0 3px, #e0e0e0 3px, #e0e0e0 6px)';
    }
    return getMaterialColor(material);
}

function scrollToDiagram(material) {
    // Sanitize material name for ID matching
    const sanitizedMaterial = material.replace(/[^a-zA-Z0-9]/g, '_');
    const diagrams = document.querySelectorAll(`[id^="diagram-${sanitizedMaterial}-"]`);
    if (diagrams.length > 0) {
        diagrams[0].scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
}

function handleCanvasClick(e, canvas) {
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    if (canvas.partData) {
        for (let partData of canvas.partData) {
            if (x >= partData.x && x <= partData.x + partData.width &&
                y >= partData.y && y <= partData.y + partData.height) {
                showPartModal(partData.part);
                break;
            }
        }
    }
}

function handleCanvasHover(e, canvas) {
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    let hovering = false;
    if (canvas.partData) {
        for (let partData of canvas.partData) {
            if (x >= partData.x && x <= partData.x + partData.width &&
                y >= partData.y && y <= partData.y + partData.height) {
                hovering = true;
                break;
            }
        }
    }
    canvas.style.cursor = hovering ? 'pointer' : 'default';
}

let scene, camera, renderer, controls, cube;
let showTexture = false, isOrthographic = false, currentPart = null;

function showPartModal(part) {
    console.log('showPartModal called with part:', part);
    const modal = document.getElementById('partModal');
    const modalCanvas = document.getElementById('modalCanvas');
    const modalInfo = document.getElementById('modalInfo');
    
    if (!modal || !modalCanvas || !modalInfo) {
        console.error('Modal elements not found');
        return;
    }
    
    let hasError = false;
    try {
        initThreeJS(part, modalCanvas);
        setupOrbitControls();
        animate();
    } catch (error) {
        console.error('Error initializing 3D:', error);
        hasError = true;
        // Hide canvas and show error message
        modalCanvas.style.display = 'none';
        const errorDiv = document.createElement('div');
        errorDiv.innerHTML = '<p style="color: #666; text-align: center; padding: 20px;">3D visualization not available (WebGL not supported)</p>';
        modalCanvas.parentNode.insertBefore(errorDiv, modalCanvas.nextSibling);
    }
    
    // Use global units and precision from app.js
    const modalUnits = window.currentUnits || 'mm';
    const modalPrecision = window.currentPrecision ?? 1; 
    const width = (part.width || 0) / window.unitFactors[modalUnits];
    const height = (part.height || 0) / window.unitFactors[modalUnits];
    const thickness = (part.thickness || 0) / window.unitFactors[modalUnits];
    const areaInM2 = (part.width * part.height / 1000000); // Always calculate area in m² for display in modal
    
    // Always show part information
    modalInfo.innerHTML = `
        <h3>${part.name}</h3>
        <p><strong>Dimensions:</strong> ${formatNumber(width, modalPrecision)} × ${formatNumber(height, modalPrecision)} × ${formatNumber(thickness, modalPrecision)} ${modalUnits}</p>
        <p><strong>Area:</strong> ${formatNumber(areaInM2, 3)} m²</p>
        <p><strong>Material:</strong> ${part.material}</p>
        <p><strong>Grain Direction:</strong> ${part.grain_direction || 'Any'}</p>
        <p><strong>Edge Banding:</strong> ${part.edge_banding || 'None'}</p>
        <p><strong>Rotated:</strong> ${part.rotated ? 'Yes' : 'No'}</p>
    `;
    
    // Setup projection toggle only if 3D worked
    const projToggle = document.getElementById('projectionToggle');
    if (projToggle && !hasError) {
        projToggle.onclick = () => {
            isOrthographic = !isOrthographic;
            projToggle.textContent = isOrthographic ? 'Perspective' : 'Orthographic';
            
            // Re-initialize camera based on projection type
            const aspect = renderer.domElement.width / renderer.domElement.height;
            const size = 10; // Arbitrary size for orthographic projection volume

            if (isOrthographic) {
                camera = new THREE.OrthographicCamera( - size * aspect / 2, size * aspect / 2, size / 2, - size / 2, 0.1, 1000 );
            } else {
                camera = new THREE.PerspectiveCamera(75, aspect, 0.1, 1000);
            }
            camera.position.set(5, 5, 5); // Reset camera position
            camera.lookAt(0,0,0);
            controls.object = camera;
            controls.update();
        };
    }
    
    currentPart = part;
    modal.style.display = 'block';
}

function initThreeJS(part, canvas) {
    scene = new THREE.Scene();
    scene.background = new THREE.Color(0xf0f0f0);
    
    camera = new THREE.PerspectiveCamera(75, canvas.width / canvas.height, 0.1, 1000);
    camera.position.set(5, 5, 5);
    
    renderer = new THREE.WebGLRenderer({ canvas: canvas, antialias: true });
    renderer.setSize(canvas.width, canvas.height);
    
    const w = (part.width || 0) / 100;
    const h = (part.height || 0) / 100; 
    const d = (part.thickness || 0) / 100;
    
    const geometry = new THREE.BoxGeometry(w, h, d);
    const material = new THREE.MeshLambertMaterial({ color: 0x74b9ff }); // Changed to Lambert for lighting
    cube = new THREE.Mesh(geometry, material);
    
    const edges = new THREE.EdgesGeometry(geometry);
    const edgeMaterial = new THREE.LineBasicMaterial({ color: 0x333333, linewidth: 1 });
    const wireframe = new THREE.LineSegments(edges, edgeMaterial);
    
    // Center the part in the scene
    geometry.computeBoundingBox();
    const center = geometry.boundingBox.getCenter(new THREE.Vector3());
    cube.position.sub(center);
    wireframe.position.sub(center);

    scene.add(cube);
    scene.add(wireframe);

    // Add lighting to make Lambert material visible
    const ambientLight = new THREE.AmbientLight(0x404040); // soft white light
    scene.add(ambientLight);
    const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
    directionalLight.position.set(1, 1, 1).normalize();
    scene.add(directionalLight);
    
    // Add edge banding visualization
    if (part.edge_banding && part.edge_banding !== 'None') {
        const bandingThickness = 0.02; // A thin band
        const bandingColor = 0xff6b35; // Orange color for banding
        const bandingMaterial = new THREE.MeshLambertMaterial({ color: bandingColor });
        
        // Define half dimensions for easier positioning
        const halfW = w / 2;
        const halfH = h / 2;
        const halfD = d / 2;

        const createBand = (bandWidth, bandHeight, bandDepth, x, y, z) => {
            const bandGeometry = new THREE.BoxGeometry(bandWidth, bandHeight, bandDepth);
            const bandMesh = new THREE.Mesh(bandGeometry, bandingMaterial);
            bandMesh.position.set(x, y, z);
            bandMesh.position.sub(center); // Apply same centering offset
            scene.add(bandMesh);
        };
        
        if (part.edge_banding.includes('All') || part.edge_banding === '4 edges') {
            // Front & Back (along X-axis, covering HxT faces)
            createBand(bandingThickness, h + bandingThickness, d + bandingThickness, -halfW - bandingThickness/2, 0, 0); // Left X face
            createBand(bandingThickness, h + bandingThickness, d + bandingThickness, halfW + bandingThickness/2, 0, 0);  // Right X face
            // Top & Bottom (along Y-axis, covering WxT faces)
            createBand(w, bandingThickness, d + bandingThickness, 0, -halfH - bandingThickness/2, 0); // Bottom Y face
            createBand(w, bandingThickness, d + bandingThickness, 0, halfH + bandingThickness/2, 0);  // Top Y face
        } else if (part.edge_banding.includes('2 edges')) {
            // Assume 2 long edges (width) - typically top and bottom faces (along X-axis)
            createBand(w, bandingThickness, d + bandingThickness, 0, -halfH - bandingThickness/2, 0); // Bottom Y face
            createBand(w, bandingThickness, d + bandingThickness, 0, halfH + bandingThickness/2, 0);  // Top Y face
        } else if (part.edge_banding.includes('1 edge')) {
            // Assume 1 long edge (width) - typically bottom face (along X-axis)
            createBand(w, bandingThickness, d + bandingThickness, 0, -halfH - bandingThickness/2, 0); // Bottom Y face
        }
    }
}

function setupOrbitControls() {
    controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.25;
    controls.enableZoom = true;
    controls.enablePan = true;
    controls.enableRotate = true;
    controls.minDistance = 1;
    controls.maxDistance = 50;
    controls.target.set(0, 0, 0); // Ensure target is centered after potential camera reset
    controls.update();
}

function animate() {
    if (!renderer || !scene || !camera || !controls) return;
    
    controls.update();
    renderer.render(scene, camera);
    
    if (document.getElementById('partModal').style.display === 'block') {
        requestAnimationFrame(animate);
    }
}

function attachPartTableClickHandlers() {
    // No additional styling needed - buttons are styled via CSS
}

function scrollToPieceDiagram(partId, boardNumber) {
    // Find the board diagram that contains this piece
    const boardIndex = boardNumber - 1; // Convert to 0-based index
    
    if (boardIndex < 0 || boardIndex >= g_boardsData.length) {
        console.warn(`Board ${boardNumber} not found`);
        return;
    }
    
    const board = g_boardsData[boardIndex];
    const diagramContainer = document.getElementById('diagramsContainer');
    
    if (!diagramContainer) {
        console.warn('Diagrams container not found');
        return;
    }
    
    // Find the canvas for this board
    const diagrams = diagramContainer.querySelectorAll('.diagram-card');
    let targetCanvas = null;
    let targetCard = null;
    
    if (boardIndex < diagrams.length) {
        targetCard = diagrams[boardIndex];
        targetCanvas = targetCard.querySelector('canvas');
    }
    
    if (!targetCanvas) {
        console.warn(`Canvas for board ${boardNumber} not found`);
        return;
    }
    
    // Clear previous highlight
    clearPieceHighlight();
    
    // Find the piece in the canvas data
    if (targetCanvas.partData) {
        for (let partData of targetCanvas.partData) {
            const partLabel = String(partData.part.instance_id || `P${partData.part.index || 0}`);
            if (partLabel === partId) {
                // Highlight this piece on the canvas
                highlightPieceOnCanvas(targetCanvas, partData);
                currentHighlightedPiece = partId;
                currentHighlightedCanvas = targetCanvas;
                break;
            }
        }
    }
    
    // Scroll the diagram card into view
    if (targetCard) {
        targetCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
}

function highlightPieceOnCanvas(canvas, partData) {
    // Redraw the canvas with the piece highlighted
    const ctx = canvas.getContext('2d');

    // Add a visual highlight by drawing a border around the piece
    ctx.strokeStyle = '#007bff';
    ctx.lineWidth = 3;

    // Draw highlight border
    ctx.strokeRect(
        partData.x - 2,
        partData.y - 2,
        partData.width + 4,
        partData.height + 4
    );
}

function copyTableAsMarkdown(tableId, button) {
    const tableContainer = document.getElementById(tableId);
    if (!tableContainer) {
        console.error(`Table or container with ID '${tableId}' not found.`);
        return;
    }
    
    const table = tableContainer.tagName === 'TABLE' ? tableContainer : tableContainer.querySelector('table');
    if (!table) {
        console.error(`No table found within container '${tableId}'.`);
        return;
    }
    
    let markdown = '';
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
        const originalContent = button.innerHTML;
        button.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20,6 9,17 4,12"/></svg>`;
        
        setTimeout(() => {
            button.classList.remove('copied');
            button.innerHTML = originalContent;
        }, 2000);
    }).catch(err => {
        console.error('Failed to copy to clipboard:', err);
        alert('Failed to copy to clipboard. Please try again.');
    });
}

function clearPieceHighlight() {
    if (currentHighlightedCanvas && currentHighlightedCanvas.boardData) {
        // Redraw the canvas to remove highlight
        redrawCanvasDiagram(currentHighlightedCanvas, currentHighlightedCanvas.boardData);
        currentHighlightedCanvas = null;
        currentHighlightedPiece = null;
    }
}

function copyFullReportAsMarkdown() {
    if (!g_reportData || !g_boardsData) {
        alert('No report data available to copy.');
        return;
    }
    
    // Use globals from app.js
    const reportUnits = window.currentUnits || 'mm';
    const reportPrecision = window.currentPrecision ?? 1;
    const currency = g_reportData.summary.currency || window.defaultCurrency || 'USD';
    const currencySymbol = window.currencySymbols[currency] || currency;
    const currentAreaUnitLabel = getAreaUnitLabel(); // Get label like 'm²'
    
    let markdown = `# AutoNestCut Report\n\n`;
    markdown += `Generated: ${new Date().toLocaleString()}\n\n`;
    
    // Overall Summary
    markdown += `## Overall Summary\n\n`;
    markdown += `| Metric | Value |\n`;
    markdown += `|--------|-------|\n`;
    markdown += `| Total Parts Instances | ${g_reportData.summary.total_parts_instances || 0} |\n`;
    markdown += `| Total Unique Part Types | ${g_reportData.summary.total_unique_part_types || 0} |\n`;
    markdown += `| Total Boards | ${g_reportData.summary.total_boards || 0} |\n`;
    markdown += `| Overall Efficiency | ${formatNumber(g_reportData.summary.overall_efficiency || 0, reportPrecision)}% |\n`;
    markdown += `| **Total Project Cost** | **${currencySymbol}${formatNumber(g_reportData.summary.total_project_cost || 0, 2)}** |\n\n`;
    
    // Unique Part Types
    markdown += `\n## Unique Part Types\n\n`;
    markdown += `| Name | W (${reportUnits}) | H (${reportUnits}) | Thick (${reportUnits}) | Material | Grain | Edge Banding | Total Qty | Total Area (${currentAreaUnitLabel}) |\n`;
    markdown += `|------|-------|-------|-----------|----------|-------|--------------|-----------|------------|\n`;
    
    if (g_reportData.unique_part_types) {
        g_reportData.unique_part_types.forEach(part_type => {
            const width = (part_type.width || 0) / window.unitFactors[reportUnits];
            const height = (part_type.height || 0) / window.unitFactors[reportUnits];
            const thickness = (part_type.thickness || 0) / window.unitFactors[reportUnits];
            
            markdown += `| ${part_type.name} | ${formatNumber(width, reportPrecision)} | ${formatNumber(height, reportPrecision)} | ${formatNumber(thickness, reportPrecision)} | ${part_type.material} | ${part_type.grain_direction} | ${part_type.edge_banding || 'None'} | ${part_type.total_quantity} | ${getAreaDisplay(part_type.total_area)} |\n`;
        });
    }
    
    // Boards Summary
    markdown += `\n## Boards Summary\n\n`;
    g_boardsData.forEach((board, index) => {
        const width = (board.stock_width || 0) / window.unitFactors[reportUnits];
        const height = (board.stock_height || 0) / window.unitFactors[reportUnits];
        
        markdown += `### ${board.material} Board ${index + 1}\n`;
        markdown += `- **Size**: ${formatNumber(width, reportPrecision)}×${formatNumber(height, reportPrecision)} ${reportUnits}\n`; // Unit included here for clarity in summary
        markdown += `- **Parts**: ${board.parts ? board.parts.length : 0}\n`;
        markdown += `- **Efficiency**: ${formatNumber(board.efficiency_percentage, 1)}%\n`;
        markdown += `- **Waste**: ${formatNumber(board.waste_percentage, 1)}%\n\n`;
        
        if (board.parts && board.parts.length > 0) {
            markdown += `**Parts on this board:**\n`;
            board.parts.forEach(part => {
                const partW = (part.width || 0) / window.unitFactors[reportUnits];
                const partH = (part.height || 0) / window.unitFactors[reportUnits];
                markdown += `- ${part.name}: ${formatNumber(partW, reportPrecision)}×${formatNumber(partH, reportPrecision)}`; // Removed unit
                if (part.edge_banding && part.edge_banding !== 'None') {
                    markdown += ` (${part.edge_banding})`;
                }
                if (part.grain_direction && part.grain_direction !== 'Any') {
                    markdown += ` [Grain: ${part.grain_direction}]`;
                }
                markdown += `\n`;
            });
            markdown += `\n`;
        }
    });
    
    // Cost Breakdown
    if (g_reportData.unique_board_types) {
        markdown += `## Cost Breakdown\n\n`;
        markdown += `| Material | Count | Total Cost |\n`;
        markdown += `|----------|-------|------------|\n`;
        
        g_reportData.unique_board_types.forEach(board_type => {
            const boardCurrency = board_type.currency || currency;
            const boardSymbol = window.currencySymbols[boardCurrency] || boardCurrency;
            markdown += `| ${board_type.material} | ${board_type.count} | ${boardSymbol}${formatNumber(board_type.total_cost || 0, 2)} |\n`;
        });
    }
    
    // Copy to clipboard
    navigator.clipboard.writeText(markdown).then(() => {
        const btn = document.getElementById('copyMarkdownButton');
        const originalHTML = btn.innerHTML; // Store original HTML with SVG
        btn.innerHTML = '✅ Copied!'; // Text-only feedback
        btn.style.background = '#28a745';
        btn.style.borderColor = '#28a745';
        btn.style.color = 'white';
        
        setTimeout(() => {
            btn.innerHTML = originalHTML; // Restore original HTML (SVG + visually hidden text)
            btn.style.background = ''; // Revert background to CSS default
            btn.style.borderColor = ''; // Revert border color
            btn.style.color = ''; // Revert text color
        }, 2000);
    }).catch(err => {
        console.error('Failed to copy to clipboard:', err);
        alert('Failed to copy to clipboard. Please try again.');
    });
}

function toggleTreeView() {
    const treeContainer = document.getElementById('treeStructure');
    const searchContainer = document.getElementById('treeSearchContainer');
    const button = document.getElementById('treeToggle');
    
    if (treeContainer.style.display === 'none' || treeContainer.style.display === '') {
        renderTreeStructure();
        treeContainer.style.display = 'block';
        searchContainer.style.display = 'flex';
        button.textContent = 'Hide Tree Structure';
    } else {
        treeContainer.style.display = 'none';
        searchContainer.style.display = 'none';
        button.textContent = 'Show Tree Structure';
    }
}

function renderTreeStructure() {
    const container = document.getElementById('treeStructure');
    if (!window.hierarchyTree || window.hierarchyTree.length === 0) {
        container.innerHTML = '<p>No hierarchy data available</p>';
        return;
    }
    
    let html = '<div class="tree-view">';
    window.hierarchyTree.forEach(component => {
        html += renderTreeNode(component, 0);
    });
    html += '</div>';
    container.innerHTML = html;
}

function renderTreeNode(node, level) {
    const indent = level * 20;
    const hasChildren = node.children && node.children.length > 0;
    const expandIcon = hasChildren ? '▼' : '•';
    
    let html = `<div class="tree-node" style="margin-left: ${indent}px;">
        <span class="tree-expand" onclick="toggleNode(this)">${expandIcon}</span>
        <span class="tree-name">${node.name || 'Unnamed'}</span>
        <span class="tree-info">(${node.material || 'No material'})</span>
    </div>`;
    
    if (hasChildren) {
        html += '<div class="tree-children">';
        node.children.forEach(child => {
            html += renderTreeNode(child, level + 1);
        });
        html += '</div>';
    }
    
    return html;
}

function toggleNode(element) {
    const children = element.parentElement.nextElementSibling;
    if (children && children.classList.contains('tree-children')) {
        if (children.style.display === 'none') {
            children.style.display = 'block';
            element.textContent = '▼';
        } else {
            children.style.display = 'none';
            element.textContent = '▶';
        }
    }
}

function filterTree() {
    const search = document.getElementById('treeSearch').value.toLowerCase();
    const nodes = document.querySelectorAll('.tree-node');
    nodes.forEach(node => {
        const text = node.textContent.toLowerCase();
        node.style.display = text.includes(search) ? 'block' : 'none';
    });
}

function clearTreeSearch() {
    document.getElementById('treeSearch').value = '';
    filterTree();
}

function expandAll() {
    document.querySelectorAll('.tree-children').forEach(el => el.style.display = 'block');
    document.querySelectorAll('.tree-expand').forEach(el => el.textContent = '▼');
}

function collapseAll() {
    document.querySelectorAll('.tree-children').forEach(el => el.style.display = 'none');
    document.querySelectorAll('.tree-expand').forEach(el => el.textContent = '▶');
}

function initResizer() {
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
}
