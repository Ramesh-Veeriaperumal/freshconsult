class AddFeatureColumnToAccounts < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :accounts, :atomic_switch => true do |m|
      m.add_column :plan_features,  "varchar(255)"
    end
  end
  
  def down
    Lhm.change_table :accounts, :atomic_switch => true do |m|
      m.remove_column :plan_features
    end
  end
end
