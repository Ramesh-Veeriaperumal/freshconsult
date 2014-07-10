class AddAccountIdToHelpdeskSlaDetails < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_sla_details, :account_id, "bigint unsigned"
  end

  def self.down
    remove_column :helpdesk_sla_details, :account_id
  end
end
