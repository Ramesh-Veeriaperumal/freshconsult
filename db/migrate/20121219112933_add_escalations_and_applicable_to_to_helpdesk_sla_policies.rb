class AddEscalationsAndApplicableToToHelpdeskSlaPolicies < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_sla_policies, :escalations, :text
    add_column :helpdesk_sla_policies, :conditions, :text
    add_column :helpdesk_sla_policies, :position, :integer
    add_column :helpdesk_sla_policies, :active, :boolean, :default => true
  end

  def self.down
    remove_column :helpdesk_sla_policies, :active
    remove_column :helpdesk_sla_policies, :position
    remove_column :helpdesk_sla_policies, :conditions
    remove_column :helpdesk_sla_policies, :escalations
  end
end
