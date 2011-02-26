class AddHelpdeskNameToAccounts < ActiveRecord::Migration
  def self.up
    add_column :accounts, :helpdesk_name, :string
    add_column :accounts, :helpdesk_url, :text
    add_column :accounts, :bg_color, :string
    add_column :accounts, :header_color, :string
    
  end

  def self.down
    remove_column :accounts, :helpdesk_name
    remove_column :accounts, :helpdesk_url
    remove_column :accounts, :bg_color
    remove_column :accounts, :header_color
    
  end
end
