class ChangeColumnHelpdeskUrlFromAccounts < ActiveRecord::Migration
  def self.up
	change_column :accounts, :helpdesk_url, :string
  end

  def self.down
	change_column :accounts, :helpdesk_url, :text
  end
end
