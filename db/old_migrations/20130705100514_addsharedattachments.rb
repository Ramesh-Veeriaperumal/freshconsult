class Addsharedattachments < ActiveRecord::Migration
  shard :none
  def self.up
    create_table :helpdesk_shared_attachments do |t|
      t.string :shared_attachable_type
      t.integer :shared_attachable_id, :limit => 8
      t.integer :attachment_id, :limit => 8
      t.integer :account_id, :limit => 8
      t.timestamps
    end
  end

  def self.down
    drop_table :helpdesk_shared_attachments
  end

end
