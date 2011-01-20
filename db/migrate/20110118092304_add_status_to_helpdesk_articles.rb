class AddStatusToHelpdeskArticles < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_articles, :status, :integer
    add_column :helpdesk_articles, :type, :integer
    add_column :helpdesk_articles, :is_public, :boolean ,:default  => true
  end

  def self.down
    remove_column :helpdesk_articles, :status
    remove_column :helpdesk_articles, :type
    remove_column :helpdesk_articles, :is_public
  end
end
