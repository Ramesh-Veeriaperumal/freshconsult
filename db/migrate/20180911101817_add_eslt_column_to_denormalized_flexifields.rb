class AddEsltColumnToDenormalizedFlexifields < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :denormalized_flexifields, atomic_switch: true do |m|
      m.add_column :eslt_text_22, 'text'
    end
  end

  def down
    Lhm.change_table :denormalized_flexifields, atomic_switch: true do |m|
      m.remove_column :eslt_text_22
    end
  end
end
