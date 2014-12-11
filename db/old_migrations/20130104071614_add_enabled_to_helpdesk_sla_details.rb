class AddEnabledToHelpdeskSlaDetails < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_sla_details, :escalation_enabled, :boolean, :default => true
  end

  def self.down
    remove_column :helpdesk_sla_details, :escalation_enabled
  end
end
