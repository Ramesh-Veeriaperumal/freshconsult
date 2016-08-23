class CreateCtiPhone < ActiveRecord::Migration

  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :cti_phones do |t|
      t.integer :account_id, :limit => 8
      t.integer :agent_id, :limit => 8
      t.string :phone
      t.integer :installed_application_id, :limit => 8
      t.timestamps
    end
    add_index :cti_phones, [:account_id, :phone], :unique => true
    add_index :cti_phones, [:account_id, :agent_id], :unique => true
  end

  def down
    drop_table :cti_phones
  end
end
