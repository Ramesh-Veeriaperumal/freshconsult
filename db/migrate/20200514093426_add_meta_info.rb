class AddMetaInfo < ActiveRecord::Migration
  shard :all

  def up
    Lhm.change_table :helpdesk_choices, atomic_switch: true do |m|
      m.remove_column :default
      m.remove_column :deleted
      m.add_column :meta, :text
      m.add_column :default, :boolean
      m.add_column :deleted, 'BOOLEAN DEFAULT false'
    end
  end

  def down
    Lhm.change_table :helpdesk_choices, atomic_switch: true do |m|
      m.remove_column :meta
      m.remove_column :default
      m.remove_column :deleted
      m.add_column :default, 'TINYINT(4)'
      m.add_column :deleted, 'TINYINT(4)'
    end
  end
end
