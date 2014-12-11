class AddIndexAttachableIdOnHelpdeskAttachments < ActiveRecord::Migration
  def self.up
	add_index :helpdesk_attachments,:attachable_id
  end

  def self.down
    remove_index :helpdesk_attachments,:attachable_id
  end
end
