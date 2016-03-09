class AddRemoteIntegratableTypeToIntegratedResources < ActiveRecord::Migration
	shard :all
	
  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :integrated_resources, :atomic_switch => true do |m|
      m.add_column :remote_integratable_type, "varchar(255) DEFAULT NULL"
      m.add_index [:account_id, :installed_application_id, :remote_integratable_id, :remote_integratable_type], "index_on_account_and_inst_app_and_remote_int_id_and_type"
    end
  end

  def down
    Lhm.change_table :integrated_resources, :atomic_switch => true do |m|
    	m.remove_index [:account_id, :installed_application_id, :remote_integratable_id, :remote_integratable_type], "index_on_account_and_inst_app_and_remote_int_id_and_type"
      m.remove_column :remote_integratable_type
    end
  end
end
