class CreateHelpdeskTicketIssues < ActiveRecord::Migration
  def self.up
    create_table :helpdesk_ticket_issues do |t|
      t.integer :ticket_id
      t.integer :issue_id
    end

    add_index :helpdesk_ticket_issues, :ticket_id
    add_index :helpdesk_ticket_issues, :issue_id
  end

  def self.down
    drop_table :helpdesk_ticket_issues
  end
end
