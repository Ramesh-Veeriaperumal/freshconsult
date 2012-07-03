class PopulateAccountIdHelpdeskTicketStates < ActiveRecord::Migration
  def self.up
    execute("update helpdesk_ticket_states hst left join helpdesk_tickets ht on hst.ticket_id=ht.id set hst.account_id=ht.account_id")
  end

  def self.down
    execute("update helpdesk_ticket_states set account_id = null")
  end
end
