class RemoveSupportPlanIdFromHelpdeskSlaDetails < ActiveRecord::Migration
  def self.up
    remove_column :helpdesk_sla_details, :support_plan_id
    add_column :helpdesk_sla_details, :sla_policy_id, :integer
  end

  def self.down
    add_column :helpdesk_sla_details, :support_plan_id, :integer
    remove_column :helpdesk_sla_details, :sla_policy_id
  end
end
