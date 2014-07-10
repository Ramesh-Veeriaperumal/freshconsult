class AddDescriptionHtmlToHelpdeskTickets < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tickets, :description_html, :text, :limit => 64.kilobytes + 1
    change_column :helpdesk_tickets, :description, :text, :limit => 64.kilobytes + 1
    add_column :helpdesk_notes, :body_html, :text, :limit => 64.kilobytes + 1
    change_column :helpdesk_notes, :body, :text, :limit => 64.kilobytes + 1
  end

  def self.down
    change_column :helpdesk_notes, :body, :text
    remove_column :helpdesk_notes, :body_html
    change_column :helpdesk_tickets, :description, :text
    remove_column :helpdesk_tickets, :description_html
  end
end
