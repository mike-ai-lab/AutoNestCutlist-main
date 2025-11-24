# Test scheduler menu item
begin
  menu = UI.menu('Extensions')
  autonest_menu = menu.add_submenu('AutoNestCut TEST')
  autonest_menu.add_item('Scheduled Exports TEST') do
    UI.messagebox("Scheduler menu works!")
  end
  puts "✅ Test menu added"
rescue => e
  puts "❌ Menu error: #{e.message}"
end