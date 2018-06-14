class AddIndexToFlexfieldDefEntries < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :flexifield_def_entries, atomic_switch: true do |m|
      m.add_index([:account_id, :flexifield_def_id, :flexifield_coltype], 'index_ffde_on_account_id_and_ff_def_id_and_ff_coltype')
    end
  end

  def down
    Lhm.change_table :flexifield_def_entries, atomic_switch: true do |m|
      m.remove_index([:account_id, :flexifield_def_id, :flexifield_coltype], 'index_ffde_on_account_id_and_ff_def_id_and_ff_coltype')
    end
  end
end
