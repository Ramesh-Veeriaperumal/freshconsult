class RemoveTypeFromHelpdeskArticles < ActiveRecord::Migration
  def self.up
    remove_column :helpdesk_articles, :type
    add_column :helpdesk_articles, :sol_type, :integer
    
  end

  def self.down
    add_column :helpdesk_articles, :type, :integer
    remove_column :helpdesk_articles, :sol_type
  end
end
