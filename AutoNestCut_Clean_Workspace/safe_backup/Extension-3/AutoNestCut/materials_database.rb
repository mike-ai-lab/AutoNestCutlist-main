require 'csv'

module AutoNestCut
  class MaterialsDatabase
    
    def self.database_file
      File.join(ENV['APPDATA'] || ENV['HOME'], 'AutoNestCut', 'materials_database.csv')
    end
    
    def self.ensure_database_folder
      folder = File.dirname(database_file)
      Dir.mkdir(folder) unless Dir.exist?(folder)
    end
    
    def self.load_database
      ensure_database_folder
      return {} unless File.exist?(database_file)
      
      materials = {}
      CSV.foreach(database_file, headers: true) do |row|
        materials[row['name']] = {
          'width' => row['width'].to_f,
          'height' => row['height'].to_f,
          'thickness' => (row['thickness'] || 18).to_f,
          'price' => row['price'].to_f,
          'currency' => row['currency'] || 'USD' # Still load currency if present, but UI now only uses default
        }
      end
      materials
    rescue => e
      Util.debug("Error loading materials database: #{e.message}")
      {}
    end
    
    def self.save_database(materials)
      ensure_database_folder
      CSV.open(database_file, 'w') do |csv|
        csv << ['name', 'width', 'height', 'thickness', 'price', 'currency']
        materials.each do |name, data|
          # Retrieve the default currency from settings to save with materials
          default_currency = Config.get_cached_settings['default_currency'] || 'USD'
          csv << [
            name,
            data['width'] || 2440,
            data['height'] || 1220,
            data['thickness'] || 18,
            data['price'] || 0,
            data['currency'] || default_currency # Use individual material currency if present, else global default
          ]
        end
      end
    rescue => e
      Util.debug("Error saving materials database: #{e.message}")
    end
    
    def self.import_csv(file_path)
      return {} unless File.exist?(file_path)
      
      materials = {}
      CSV.foreach(file_path, headers: true) do |row|
        name = row['name'] || row['material'] || row['Material']
        next unless name
        
        # When importing, use global default currency if not specified in CSV
        default_currency = Config.get_cached_settings['default_currency'] || 'USD'
        materials[name] = {
          'width' => (row['width'] || row['Width'] || 2440).to_f,
          'height' => (row['height'] || row['Height'] || 1220).to_f,
          'thickness' => (row['thickness'] || row['Thickness'] || 18).to_f, # Ensure thickness is imported
          'price' => (row['price'] || row['Price'] || 0).to_f,
          'currency' => row['currency'] || row['Currency'] || default_currency,
          'supplier' => row['supplier'] || row['Supplier'] || '',
          'notes' => row['notes'] || row['Notes'] || ''
        }
      end
      materials
    rescue => e
      Util.debug("Error importing CSV: #{e.message}")
      {}
    end
    
    def self.get_default_materials
      # Use global default currency for default materials too
      default_currency = Config.get_cached_settings['default_currency'] || 'USD'
      {
        'Plywood_19mm' => { 'width' => 2440, 'height' => 1220, 'thickness' => 19, 'price' => 45, 'currency' => default_currency },
        'Plywood_12mm' => { 'width' => 2440, 'height' => 1220, 'thickness' => 12, 'price' => 35, 'currency' => default_currency },
        'MDF_16mm' => { 'width' => 2440, 'height' => 1220, 'thickness' => 16, 'price' => 25, 'currency' => default_currency },
        'MDF_19mm' => { 'width' => 2440, 'height' => 1220, 'thickness' => 19, 'price' => 30, 'currency' => default_currency },
        'Oak_Veneer' => { 'width' => 2440, 'height' => 1220, 'thickness' => 18, 'price' => 85, 'currency' => default_currency },
        'Melamine_White' => { 'width' => 2440, 'height' => 1220, 'thickness' => 18, 'price' => 40, 'currency' => default_currency }
      }
    end
    
    # This method is for backend internal use. Frontend uses global currencySymbols.
    def self.get_supported_currencies
      # Keeping a comprehensive list, but UI only shows a subset.
      # This is useful for CSV import/export validation or future features.
      {
        'USD' => '$',
        'EUR' => '€',
        'GBP' => '£',
        'CAD' => 'C$',
        'AUD' => 'A$',
        'JPY' => '¥',
        'CNY' => '¥',
        'INR' => '₹',
        'BRL' => 'R$',
        'MXN' => '$',
        'CHF' => 'CHF',
        'SEK' => 'kr',
        'NOK' => 'kr',
        'DKK' => 'kr',
        'PLN' => 'zł',
        'CZK' => 'Kč',
        'HUF' => 'Ft',
        'RUB' => '₽',
        'TRY' => '₺',
        'ZAR' => 'R',
        'KRW' => '₩',
        'SGD' => 'S$',
        'HKD' => 'HK$',
        'NZD' => 'NZ$',
        'THB' => '฿',
        'MYR' => 'RM',
        'IDR' => 'Rp',
        'PHP' => '₱',
        'VND' => '₫',
        'ILS' => '₪',
        'AED' => 'د.إ',
        'SAR' => 'ر.س',
        'EGP' => 'ج.م',
        'QAR' => 'ر.ق',
        'KWD' => 'د.ك',
        'BHD' => 'د.ب',
        'OMR' => 'ر.ع.',
        'JOD' => 'د.ا',
        'LBP' => 'ل.ل',
        'MAD' => 'د.م.',
        'TND' => 'د.ت',
        'DZD' => 'د.ج',
        'LYD' => 'ل.د',
        'SDG' => 'ج.س.',
        'SOS' => 'S',
        'ETB' => 'Br',
        'KES' => 'KSh',
        'UGX' => 'USh',
        'TZS' => 'TSh',
        'RWF' => 'RF',
        'BIF' => 'FBu',
        'DJF' => 'Fdj',
        'ERN' => 'Nfk',
        'MGA' => 'Ar',
        'MUR' => '₨',
        'SCR' => '₨',
        'KMF' => 'CF',
        'MWK' => 'MK',
        'ZMW' => 'ZK',
        'BWP' => 'P',
        'SZL' => 'L',
        'LSL' => 'L',
        'NAD' => 'N$',
        'AOA' => 'Kz',
        'MZN' => 'MT',
        'ZWL' => 'Z$',
        'GMD' => 'D',
        'SLL' => 'Le',
        'LRD' => 'L$',
        'GHS' => '₵',
        'NGN' => '₦',
        'XOF' => 'CFA',
        'XAF' => 'FCFA',
        'CVE' => '$',
        'STD' => 'Db',
        'GNF' => 'FG',
        'CDF' => 'FC',
        'XPF' => '₣',
        'FJD' => 'FJ$',
        'SBD' => 'SI$',
        'VUV' => 'VT',
        'TOP' => 'T$',
        'WST' => 'WS$',
        'PGK' => 'K',
        'TVD' => '$',
        'NRU' => '$',
        'KID' => '$',
        'CKD' => '$',
        'NUD' => '$'
      }
    end
    
    def self.format_price(price, currency = 'USD')
      symbol = get_supported_currencies[currency] || currency
      "#{symbol}#{price.round(2)}"
    end
    
  end
end
