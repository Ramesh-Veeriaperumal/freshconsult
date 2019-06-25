module ApiAdminAccountsControllerMethods
  include AccountsConstants

  def fetch_unresolved_tickets(user_email)
    unresolved_tickets = []
    contacts_url = CONTACTS_URL % { user_email: user_email }
    user_details = fetch_details_from_support(contacts_url).first
    if user_details.present?
      user_details.symbolize_keys!
      company_id = user_details[:company_id]
      unresolved_tickets = fetch_ticket_details(user_details, company_id)
    end
    unresolved_tickets
  end
  
  def fetch_ticket_details(user_details, company_id)
    unresolved_ticket_list = []
    ticket_url = if company_id.present?
                   TICKET_URL_WITH_COMPANY % { company_id: company_id }.merge!(fetch_support_params)
                 else
                   TICKET_URL_WITHOUT_COMPANY % { requester_id: user_details[:id] }.merge!(fetch_support_params)
                 end
    ticket_list = fetch_details_from_support(ticket_url)
    ticket_list.each do |ticket|
      unless ticket['status'] == Helpdesk::Ticketfields::TicketStatus::RESOLVED || ticket['status'] == Helpdesk::Ticketfields::TicketStatus::CLOSED
        unresolved_ticket_list << ticket
      end
    end
    unresolved_ticket_list
  end

  def fetch_details_from_support(support_url)
    JSON.parse(RestClient::Request.new(user: PRODUCT_FEEDBACK_CONFIG['api_key'], method: :get, url: support_url).execute)
  end

  def fetch_support_params
    updated_since_date = (Time.now - 3.month).utc.iso8601
    { :per_page_count => 100, :updated_since_date => updated_since_date }
  end
end
