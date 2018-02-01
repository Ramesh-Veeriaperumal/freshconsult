class AddBotIdToPortalSolutionCategories < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :portal_solution_categories, :atomic_switch => true do |m|
      m.add_column :bot_id, :integer
    end
  end
  
  def down
    Lhm.change_table :portal_solution_categories, :atomic_switch => true do |m|
      m.remove_column :bot_id
    end
  end
end
