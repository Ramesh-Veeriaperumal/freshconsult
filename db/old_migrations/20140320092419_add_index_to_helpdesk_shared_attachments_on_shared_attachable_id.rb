class AddIndexToHelpdeskSharedAttachmentsOnSharedAttachableId < ActiveRecord::Migration
  shard :all
  def self.up
  	Lhm.change_table :helpdesk_shared_attachments, :atomic_switch => true do |m|
  		m.add_index  [:account_id, :shared_attachable_id] , 'index_helpdesk_attachement_shared_id_share_id'
  	end
  end

  def self.down
  	Lhm.change_table :helpdesk_shared_attachments, :atomic_switch => true do |m|
  		m.remove_index [:account_id, :shared_attachable_id] ,'index_helpdesk_attachement_shared_id_share_id'
  	end
  end
end
