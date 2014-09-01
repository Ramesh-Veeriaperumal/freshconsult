class AddIndexTaggableToHelpdeskTagUses < ActiveRecord::Migration
  def self.up
  	execute("alter table `helpdesk_tag_uses` add index `helpdesk_tag_uses_taggable` (`taggable_id`,`taggable_type`(10))")
  end

  def self.down
  	execute("alter table `helpdesk_tag_uses` drop index `helpdesk_tag_uses_taggable`") 
  end
end
