class AddMltColumnsToDenormalizedFlexifields < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :denormalized_flexifields, atomic_switch: true do |m|
      m.add_column :mlt_text_17, 'text'
      m.add_column :mlt_text_18, 'text'
      m.add_column :mlt_text_19, 'text'
      m.add_column :mlt_text_20, 'text'
      m.add_column :mlt_text_21, 'text'
      m.add_column :lock_version, 'integer DEFAULT \'0\''
    end
  end

  def down
    Lhm.change_table :denormalized_flexifields, atomic_switch: true do |m|
      m.remove_column :mlt_text_17
      m.remove_column :mlt_text_18
      m.remove_column :mlt_text_19
      m.remove_column :mlt_text_20
      m.remove_column :mlt_text_21
      m.remove_column :lock_version
    end
  end
end
