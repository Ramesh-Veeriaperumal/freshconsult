class AddIndexForRemoteIntegrationMappingOnAccountId < ActiveRecord::Migration
  shard :none
  
  def up
    Lhm.change_table :remote_integrations_mappings, :atomic_switch => true do |m|
      m.add_index [:account_id, :type], "account_id_type_index"
    end
  end

  def down
    Lhm.change_table :remote_integrations_mappings, :atomic_switch => true do |m|
      m.remove_index "account_id_type_index"
    end
  end
end
