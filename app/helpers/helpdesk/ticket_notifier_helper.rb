module Helpdesk::TicketNotifierHelper

  include Admin::CustomSurveysHelper

	def hidden_ticket_identifier(ticket)
		%(<span title="fd_tkt_identifier" style='font-size:0px; font-family:"fdtktid"; min-height:0px; height:0px; opacity:0; max-height:0px; line-height:0px; color:#ffffff'>#{ticket.display_id}</span>).html_safe
	end

  def survey_url(ticket, rating, id_token)
    support_customer_survey_url(id_token, Survey::CUSTOMER_RATINGS[rating], 
      :host => ticket.portal_host)
  end

end
