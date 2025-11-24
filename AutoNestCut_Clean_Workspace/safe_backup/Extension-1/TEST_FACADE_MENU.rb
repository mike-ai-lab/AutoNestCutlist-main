# Test facade menu directly
begin
  menu = UI.menu('Extensions')
  autonest_menu = menu.add_submenu('AutoNestCut FACADE TEST')
  autonest_menu.add_item('Facade Materials Calculator') do
    UI.messagebox("Facade calculator would open here!")
  end
  puts "✅ Facade test menu added"
rescue => e
  puts "❌ Menu error: #{e.message}"
end