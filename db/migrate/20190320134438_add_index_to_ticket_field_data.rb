class AddIndexToTicketFieldData < ActiveRecord::Migration
  shard(:all)

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :ticket_field_data, atomic_switch: true do |m|
      m.remove_index [:account_id, :flexifield_set_id], 'index_flexifields_on_flexifield_def_id_and_flexifield_set_id'
      m.add_unique_index [:account_id, :flexifield_set_id], 'unique_index_flexifields_on_account_id_and_flexifield_set_id'
    end
  end

  def down
    Lhm.change_table :ticket_field_data, atomic_switch: true do |m|
      m.remove_index [:account_id, :flexifield_set_id], 'unique_index_flexifields_on_account_id_and_flexifield_set_id'
      m.add_index [:account_id, :flexifield_set_id], 'index_flexifields_on_flexifield_def_id_and_flexifield_set_id'
    end
  end
end
