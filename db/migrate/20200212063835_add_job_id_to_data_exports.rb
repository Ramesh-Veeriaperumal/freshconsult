class AddJobIdToDataExports < ActiveRecord::Migration
  shard :all

  def self.up
    Lhm.change_table :data_exports, atomic_switch: true do |m|
      m.add_column :job_id, 'varchar(30)'
      m.add_column :export_params, 'text'
      m.add_index [:account_id, :job_id], 'index_data_exports_on_account_id_and_job_id'
    end
  end

  def self.down
    Lhm.change_table :data_exports, atomic_switch: true do |m|
      m.remove_column :job_id
      m.remove_column :export_params
      m.remove_index [:account_id, :job_id], 'index_data_exports_on_account_id_and_job_id'
    end
  end
end
