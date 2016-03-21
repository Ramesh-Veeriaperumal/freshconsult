class AddUserIdToRemoteIntegrationsMappings < ActiveRecord::Migration
  shard :none

  def up
  	Integrations::HootsuiteRemoteUser.delete_all
  	Lhm.change_table :remote_integrations_mappings, :atomic_switch => true do |m|
      m.add_column :user_id, "bigint(20) unsigned DEFAULT NULL"
      m.add_index [:account_id, :user_id, :type], "index_on_account_id_user_id_type"
    end
  end

  def down
  	Lhm.change_table :remote_integrations_mappings, :atomic_switch => true do |m|
      m.remove_column :user_id
      m.remove_index [:account_id, :user_id, :type], "index_on_account_id_user_id_type"
    end
  end
end
