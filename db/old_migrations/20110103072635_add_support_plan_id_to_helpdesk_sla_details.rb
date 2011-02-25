class AddSupportPlanIdToHelpdeskSlaDetails < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_sla_details, :support_plan_id, :integer
  end

  def self.down
    remove_column :helpdesk_sla_details, :support_plan_id
  end
end
