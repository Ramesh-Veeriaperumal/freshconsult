class CreateDenormalizedFlexifields < ActiveRecord::Migration
  shard :all
  def up
    create_table :denormalized_flexifields do |t|
      t.references :account, :limit => 8
      t.integer  "flexifield_id",      :limit => 8
      t.text     "text_01"
      t.text     "text_02"
      t.text     "text_03"
      t.text     "text_04"
      t.text     "text_05"
      t.text     "text_06"
      t.text     "text_07"
      t.text     "text_08"
      t.text     "text_09"
      t.text     "text_10"
      t.text     "slt_text_11"
      t.text     "slt_text_12"
      t.text     "int_text_13"
      t.text     "decimal_text_14"
      t.text     "date_text_15"
      t.text     "boolean_text_16"
      t.timestamps
    end

    add_index :denormalized_flexifields, [:account_id, :flexifield_id]
  end

  def down
    drop_table :denormalized_flexifields
  end
end
