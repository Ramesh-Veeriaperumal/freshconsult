class CreateChatSettings < ActiveRecord::Migration
  shard :none
  def self.up
    create_table :chat_settings do |t|
      t.integer :account_id, :limit => 8
      t.text :display_id
      t.text :preferences
      t.string :minimized_title
      t.string :maximized_title
      t.string :welcome_message
      t.string :thank_message
      t.string :wait_message
      t.string :typing_message
      t.integer :prechat_form
      t.string :prechat_message
      t.integer :prechat_phone
      t.integer :prechat_mail
      t.integer :proactive_chat
      t.integer :proactive_time

      t.timestamps
    end
  end

  def self.down
    drop_table :chat_settings
  end
end
