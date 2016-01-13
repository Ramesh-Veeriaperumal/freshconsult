class IntegrationUserCredentialsAddRemoteUserIdIndex < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :integrations_user_credentials, :atomic_switch => true do |m|
      m.add_unique_index [:account_id,:installed_application_id, :remote_user_id], "index_on_account_and_installed_app_and_remote_user_id"
    end
  end
  
  def down
    Lhm.change_table :integrations_user_credentials, :atomic_switch => true do |m|
      m.remove_index [:account_id, :installed_application_id, :remote_user_id], "index_on_account_and_installed_app_and_remote_user_id"
    end
  end
end
