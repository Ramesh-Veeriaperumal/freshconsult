class AddIndexToHelpdeskSharedAttachmentsOnSharedAttachableId < ActiveRecord::Migration
  shard :all
  def self.up
  	add_index :helpdesk_shared_attachments, [:account_id, :shared_attachable_id], :name => 'index_helpdesk_shared_attachments_on_account_id_shared_attachable_id'
  end

  def self.down
  	remove_index(:helpdesk_shared_attachments, :name => 'index_helpdesk_shared_attachments_on_account_id_shared_attachable_id')
  end
end
