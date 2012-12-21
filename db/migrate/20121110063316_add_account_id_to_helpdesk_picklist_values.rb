class AddAccountIdToHelpdeskPicklistValues < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_picklist_values, :account_id, "bigint unsigned"
  end

  def self.down
    remove_column :helpdesk_picklist_values, :account_id
  end
end
