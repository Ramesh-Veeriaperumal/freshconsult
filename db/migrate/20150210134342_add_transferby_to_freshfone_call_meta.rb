class AddTransferbyToFreshfoneCallMeta < ActiveRecord::Migration
  shard :all

  def up
    Lhm.change_table :freshfone_calls_meta, :atomic_switch => true do |m|
      m.add_column :transfer_by_agent ,  'bigint(20) unsigned DEFAULT NULL'
    end
  end

  def down
    Lhm.change_table :freshfone_calls_meta, :atomic_switch => true do |m|
      m.remove_column :transfer_by_agent
    end
  end
end
