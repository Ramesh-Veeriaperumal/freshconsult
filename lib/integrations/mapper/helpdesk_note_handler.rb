class Integrations::Mapper::HelpdeskNoteHandler < Integrations::Mapper::DBHandler
  def create(data, config)
    ticket = Helpdesk::Ticket.find_by_account_id(data["account_id"], :joins=>"INNER JOIN integrated_resources ON integrated_resources.local_integratable_id=helpdesk_tickets.id", 
		    :conditions=>["integrated_resources.remote_integratable_id=?", data["issue"]["key"]])
    ticket.notes.new unless ticket.blank?
  end
end
