class Workers::PopulateTicketFormFieldsWorker
  extend Resque::AroundPerform
  @queue = 'populate_form_fields'

  class << self

  	include Helpdesk::Ticketfields::TicketFormFields

	  def perform args
	    populate_data(Account.current)
	  end

	  def populate_data(account)
			tkt_fields = account.ticket_fields
			tkt_fields.each do |tkt_field|
				save_form_field(tkt_field)
				if(tkt_field.field_type == 'nested_field')
					tkt_field.nested_ticket_fields.each do |nested_field|
						save_form_nested_field(nested_field)
					end
				end
			end
		end
	end

end