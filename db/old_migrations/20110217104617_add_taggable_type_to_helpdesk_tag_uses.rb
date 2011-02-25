class AddTaggableTypeToHelpdeskTagUses < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tag_uses, :taggable_type, :string
    add_column :helpdesk_tag_uses, :taggable_id, :integer
    remove_column :helpdesk_tag_uses, :ticket_id
  end

  def self.down
    add_column :helpdesk_tag_uses, :ticket_id, :integer
    remove_column :helpdesk_tag_uses, :taggable_id
    remove_column :helpdesk_tag_uses, :taggable_type
  end
end
