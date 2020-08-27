# frozen_string_literal: true

class AddColumnUidToGroups < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :groups, atomic_switch: true do |m|
      m.add_column :uid, 'varchar(255) DEFAULT NULL'
      m.add_index [:account_id, :uid], 'index_account_id_uid_on_groups'
    end
  end

  def down
    Lhm.change_table :groups, atomic_switch: true do |m|
      m.remove_column :uid
      m.remove_index [:account_id, :uid], 'index_account_id_uid_on_groups'
    end
  end
end
