# Minimal scheduler test
require 'json'

module AutoNestCut
  def self.show_scheduler
    UI.messagebox("Scheduler dialog would open here!")
  end
  
  def self.setup_minimal_menu
    menu = UI.menu('Extensions')
    autonest_menu = menu.add_submenu('AutoNestCut SCHEDULER TEST')
    autonest_menu.add_item('Scheduled Exports') { AutoNestCut.show_scheduler }
    puts "✅ Minimal scheduler menu added"
  end
end

AutoNestCut.setup_minimal_menu