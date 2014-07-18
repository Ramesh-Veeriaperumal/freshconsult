class AddHeadToPortalTemplates < ActiveRecord::Migration
  shard :shard_1
    
  def self.up
    add_column :portal_templates, :head, :text
  end

  def self.down
    remove_column :portal_templates, :head
  end
end
