class AddHeadToPortalTemplates < ActiveRecord::Migration
  shard :all
    
  def self.up
    Lhm.change_table :portal_templates, :atomic_switch => true do |m|
      m.add_column :head, "text COLLATE utf8_unicode_ci DEFAULT NULL"
    end
  end

  def self.down
    Lhm.change_table :portal_templates, :atomic_switch => true do |m|
      m.remove_column :head
    end
  end
end
