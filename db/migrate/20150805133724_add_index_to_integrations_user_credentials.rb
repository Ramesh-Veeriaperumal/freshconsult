class AddIndexToIntegrationsUserCredentials < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :integrations_user_credentials, :atomic_switch => true do |m|
      m.add_unique_index [:account_id,:installed_application_id,:user_id], "index_on_account_and_installed_app_and_user_id"
      m.add_column :remote_user_id, "varchar(255) DEFAULT NULL"
    end
  end
  
  def down
    Lhm.change_table :integrations_user_credentials, :atomic_switch => true do |m|
      m.remove_index [:account_id,:installed_application_id,:user_id], "index_on_account_and_installed_app_and_user_id"
      m.remove_column :remote_user_id
    end
  end
end
  