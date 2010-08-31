class AddCounterToIssue < ActiveRecord::Migration
  def self.up
      add_column :helpdesk_issues, :ticket_issues_count, :integer
  end

  def self.down
      remove_column :helpdesk_issues, :ticket_issues_count
  end
end
