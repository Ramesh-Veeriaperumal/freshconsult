class AddOverrideBhrsToHelpdeskSlaDetails < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_sla_details, :override_bhrs, :boolean , :default =>false
    remove_column :helpdesk_sla_details, :account_id
  end

  def self.down
    remove_column :helpdesk_sla_details, :override_bhrs
    add_column :helpdesk_sla_details, :account_id, :integer
  end
end
