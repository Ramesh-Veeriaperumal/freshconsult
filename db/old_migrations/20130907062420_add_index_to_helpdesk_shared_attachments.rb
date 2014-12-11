class AddIndexToHelpdeskSharedAttachments < ActiveRecord::Migration
  shard :none
  def self.up
    execute("alter table helpdesk_shared_attachments 
      add index `index_helpdesk_shared_attachments_on_attachable_id` 
      (`account_id`,`shared_attachable_id`,`shared_attachable_type`(15))")
  end

  def self.down
  end
end
