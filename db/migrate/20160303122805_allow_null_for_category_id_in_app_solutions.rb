class AllowNullForCategoryIdInAppSolutions < ActiveRecord::Migration
  shard :all
  
  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :mobihelp_app_solutions, :atomic_switch => true do |m|
      m.change_column :category_id, "bigint(20)"
    end
  end

  def down
    Lhm.change_table :mobihelp_app_solutions, :atomic_switch => true do |m|
      m.change_column :category_id, "bigint(20) NOT NULL"
    end
  end
end
