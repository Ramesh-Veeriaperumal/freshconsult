class CreateChats < ActiveRecord::Migration
  shard :none
  def self.up
    create_table :chats do |t|
      t.integer :account_id, :limit => 8
      t.string :title_min
      t.string :title_max
      t.string :welcome_msg
      t.string :onhold_msg
      t.string :prechat_msg
      t.integer :prechat_name
      t.integer :prechat_phone
      t.integer :prechat_mail
      t.integer :greet_time
      t.string :greet_msg

      t.timestamps
    end
  end

  def self.down
    drop_table :chats
  end
end
