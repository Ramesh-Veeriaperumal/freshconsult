class CreateFailedHelpkitFeedsTable < ActiveRecord::Migration
  shard :none

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :failed_helpkit_feeds do |t|
      t.integer :account_id, limit: 8, null: false
      t.string :uuid, limit: 255
      t.string :exchange, limit: 20
      t.string :routing_key, limit: 20
      t.text :payload
      t.string :exception, limit: 255

      t.timestamps null: false
    end

    # Possible queries:
    #------------------
    # select * from failed_helpkit_feeds where account_id = ?
    # select * from failed_helpkit_feeds where created_at >= ? and created_at <= ?
    # select * from failed_helpkit_feeds where account_id = ? and created_at >= ? and created_at <= ?
    # select * from failed_helpkit_feeds where uuid = ?
    # select * from failed_helpkit_feeds where account_id = ? and uuid = ?
    
    # Adjust keys based on necessity
    add_index :failed_helpkit_feeds, :uuid
    add_index :failed_helpkit_feeds, :account_id
    add_index :failed_helpkit_feeds, :created_at
  end
  
  def down
    drop_table :failed_helpkit_feeds
  end
end