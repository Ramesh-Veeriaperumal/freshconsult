class PopulateAccountIdOnHelpdeskSlaDetails < ActiveRecord::Migration
  def self.up
  	execute("UPDATE helpdesk_sla_details INNER JOIN helpdesk_sla_policies ON helpdesk_sla_details.sla_policy_id=helpdesk_sla_policies.id SET helpdesk_sla_details.account_id=helpdesk_sla_policies.account_id")
  end

  def self.down
  	execute("UPDATE helpdesk_sla_details SET account_id=null")
  end
end
