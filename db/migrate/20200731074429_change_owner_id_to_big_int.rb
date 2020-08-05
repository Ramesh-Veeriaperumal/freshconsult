class ChangeOwnerIdToBigInt < ActiveRecord::Migration
  shard :all
  def up
    Lhm.change_table :archive_tickets, atomic_switch: true do |m|
      m.change_column :owner_id, 'bigint(20)'
    end
  end

  def down
    Lhm.change_table :archive_tickets, atomic_switch: true do |m|
      m.change_column :owner_id, 'int(11)'
    end
  end
end
