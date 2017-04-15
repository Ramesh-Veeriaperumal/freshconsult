class CreateScheduledExports < ActiveRecord::Migration
  shard :all
  def self.up
    create_table :scheduled_exports do |t|
      t.string  :name
      t.text    :description
      t.integer :user_id
      t.text    :filter_data
      t.text    :fields_data
      t.text    :schedule_details
      t.integer :account_id
      t.string  :latest_file
      t.integer :schedule_type, :limit => 2
      t.boolean :active, :default => false
      t.timestamps
    end
    add_index :scheduled_exports, :account_id, :name => "index_scheduled_exports_on_account_id"
  end

  def self.down
    drop_table :scheduled_exports
  end
end