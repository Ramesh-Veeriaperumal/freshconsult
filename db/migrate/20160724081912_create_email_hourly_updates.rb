class CreateEmailHourlyUpdates < ActiveRecord::Migration

  shard :none
  
  def self.up
    create_table :email_hourly_updates do |t|
      t.string :received_host
      t.string :hourly_path
      t.datetime :locked_at
      t.string :state
      t.timestamps
    end

    add_index :email_hourly_updates, :hourly_path, :unique => true
  end

  def self.down
    drop_table :email_hourly_updates
  end
end
