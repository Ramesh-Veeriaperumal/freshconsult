class AddAccountIdToHelpdeskTickets < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tickets, :account_id, :integer
    add_column :helpdesk_tags, :account_id, :integer
    add_column :helpdesk_notes, :account_id, :integer
    add_column :helpdesk_guides, :account_id, :integer
    add_column :helpdesk_attachments, :account_id, :integer
    add_column :helpdesk_articles, :account_id, :integer
  end

  def self.down
    remove_column :helpdesk_tickets, :account_id
    remove_column :helpdesk_tags, :account_id
    remove_column :helpdesk_notes, :account_id
    remove_column :helpdesk_guides, :account_id
    remove_column :helpdesk_attachments, :account_id
    remove_column :helpdesk_articles, :account_id
  end
end
