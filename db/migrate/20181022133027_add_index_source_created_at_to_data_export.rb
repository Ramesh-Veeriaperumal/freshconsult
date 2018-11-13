class AddIndexSourceCreatedAtToDataExport < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :data_exports, atomic_switch: true do |m|
      m.add_index([:source, :created_at], 'index_data_exports_on_source_and_created_at')
    end
  end

  def down
    Lhm.change_table :data_exports, atomic_switch: true do |m|
      m.remove_index([:source, :created_at], 'index_data_exports_on_source_and_created_at')
    end
  end
end
