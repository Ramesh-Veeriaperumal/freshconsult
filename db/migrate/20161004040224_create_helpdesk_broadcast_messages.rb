class CreateHelpdeskBroadcastMessages < ActiveRecord::Migration
  shard :all
  
  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :helpdesk_broadcast_messages do |t|
      t.column  :account_id, "bigint unsigned"
      t.integer :tracker_display_id, :limit => 8
      t.integer :note_id,            :limit => 8
      t.text    :body,               :limit => 16777215
      t.text    :body_html,          :limit => 16777215
      t.timestamps
    end

    add_index :helpdesk_broadcast_messages, [:account_id, :tracker_display_id], :name => "index_broadcast_messages_on_account_id_tracker_display_id"
  end

  def down
    drop_table :helpdesk_broadcast_messages
  end

end
