class RenameSlaPoliciesAndSlaDetailsTables < ActiveRecord::Migration
  def self.up
  	rename_table :helpdesk_sla_policies, :sla_policies
  	rename_table :helpdesk_sla_details, :sla_details
  end

  def self.down
  	rename_table :sla_policies, :helpdesk_sla_policies
  	rename_table :sla_details, :helpdesk_sla_details
  end
end
