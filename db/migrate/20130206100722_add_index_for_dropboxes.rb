class AddIndexForDropboxes < ActiveRecord::Migration
  def self.up
  	execute "alter table helpdesk_dropboxes add index `helpdesk_dropboxes_id` (`id`),
  	drop primary key,
  	add index index_helpdesk_dropboxes_on_droppable_id (account_id,droppable_id,droppable_type) 
  	PARTITION BY HASH(account_id) PARTITIONS 128"
  end

  def self.down
  end
end
