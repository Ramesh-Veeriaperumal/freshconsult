class Helpdesk::TicketBodyWeekly < Helpdesk::Mysql::DynamicTable
  def self.find_ticket_body(table_name,ticket_id,account_id)
    self.table_name = table_name
    self.find_by_ticket_id_and_account_id(ticket_id,account_id)
  end
end
