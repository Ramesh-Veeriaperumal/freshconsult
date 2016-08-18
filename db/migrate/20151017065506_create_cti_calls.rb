class CreateCtiCalls < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :cti_calls do |t|
      t.string :call_sid
      t.string :recordable_type
      t.integer :recordable_id, :limit => 8
      t.integer :account_id, :limit => 8
      t.integer :responder_id, :limit => 8
      t.integer :requester_id, :limit => 8
      t.integer :installed_application_id, :limit => 8
      t.text :options
      t.integer :status, :limit => 8
      t.timestamps
  	end
    add_index :cti_calls, [:account_id, :call_sid]
    add_index :cti_calls, [:account_id, :responder_id, :status]
    add_index :cti_calls, [:account_id, :created_at]
    add_index :cti_calls, [:account_id, :recordable_type, :recordable_id], :name => "index_cti_call_on_account_id_and_recordable"
  end

  def down
  	drop_table :cti_calls
  end
end
