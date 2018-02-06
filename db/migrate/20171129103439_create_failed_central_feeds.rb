class CreateFailedCentralFeeds < ActiveRecord::Migration
  shard :none

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :failed_central_feeds, :force => true do |t|
      t.integer :account_id, limit: 8, null: false
      t.integer :model_id, limit: 8, null: false
      t.string  :uuid, limit: 255
      t.string  :payload_type, limit: 255
      t.text    :model_changes
      t.text    :additional_info
      t.string  :exception, limit: 255

      t.timestamps null: false
    end

    add_index :failed_central_feeds, :uuid
    add_index :failed_central_feeds, :model_id
    add_index :failed_central_feeds, :account_id
    add_index :failed_central_feeds, :created_at
  end
  
  def down
    drop_table :failed_central_feeds
  end
end