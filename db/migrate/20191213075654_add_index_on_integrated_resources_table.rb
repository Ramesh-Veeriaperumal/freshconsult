class AddIndexOnIntegratedResourcesTable < ActiveRecord::Migration
  shard :all
  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :integrated_resources, atomic_switch: true do |m|
      m.add_index [:account_id, :local_integratable_id, :local_integratable_type], 'index_on_account_id_and_local_integratable_id_and_type'
    end
  end

  def down
    Lhm.change_table :integrated_resources, atomic_switch: true do |m|
      m.remove_index [:account_id, :local_integratable_id, :local_integratable_type], 'index_on_account_id_and_local_integratable_id_and_type'
    end
  end
end
