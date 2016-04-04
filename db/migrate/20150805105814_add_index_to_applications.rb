class AddIndexToApplications < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end
    
  def up
    Lhm.change_table :applications, :atomic_switch => true do |m|
      m.add_index [:name], "index_applications_on_name"
      m.add_index [:account_id], "index_applications_on_account_id"
    end
  end

  def down
    Lhm.change_table :applications, :atomic_switch => true do |m|
      m.remove_index [:name], "index_applications_on_name"
      m.remove_index [:account_id] ,"index_applications_on_account_id"
    end
  end
  
end
