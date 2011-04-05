class AddIndexHelpdeskUrlOnAccounts < ActiveRecord::Migration
  def self.up
	add_index :accounts,:helpdesk_url
  end

  def self.down
	remove_index :accounts,:helpdesk_url
  end
end
