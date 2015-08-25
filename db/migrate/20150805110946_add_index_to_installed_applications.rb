class AddIndexToInstalledApplications < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :installed_applications, :atomic_switch => true do |m|
      m.add_index [:account_id, :application_id], "index_installed_applications_on_account_id_and_application_id"
    end
  end
  
  def down
    Lhm.change_table :installed_applications, :atomic_switch => true do |m|
      m.remove_index [:account_id,:application_id], "index_installed_applications_on_account_id_and_application_id"
    end
  end
end
