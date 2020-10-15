fixtures_data = SANDBOX_FIXTURES[:data]


def self.account
  @account = Account.current
end

def self.create_requester(params)
  requester = User.find_by_email_and_account_id(params[:email],account.id)
  return requester if requester
  User.seed(:account_id, :email) do |s|
    s.account_id = account.id
    s.email      = params[:email]
    s.name       = params[:name]
  end
end

def self.create_company(params)
  Company.seed(:account_id, :name) do |s|
    s.account_id  = account.id
    s.name        = params[:company_name]
    s.domains      = params[:company_url].to_s
  end
end

def self.create_user_companies(user, params)
  company = create_company(params)
  UserCompany.seed(:account_id, :user_id, :company_id) do |s|
    s.account_id  = account.id
    s.user_id     = user.id
    s.company_id  = company.id
  end
end

fixtures_data.each do |data|
  begin
    data.symbolize_keys!
    # create requester if not present
    requester = create_requester(data)
    ticket = Helpdesk::Ticket.seed(:account_id, :subject) do |s|
        s.account_id  = account.id
        s.subject     = data[:subject] #I18
        s.email       = requester.email
        s.status      = Helpdesk::TicketStatus::DEFAULT_STATUSES.keys.sample
        s.source      = Helpdesk::Source.default_ticket_source_keys_by_token.keys.sample
        s.priority    = TicketConstants::PRIORITY_KEYS_BY_TOKEN.keys.sample
        s.disable_observer_rule   = true
        s.ticket_body_attributes  = {:description => data[:description], :description_html => data[:description_html] }
        s.disable_activities      = true
    end
    ticket.save
    create_user_companies(requester, data) if data[:company_name]
  rescue => e
    Rails.logger.error("Error while creating sample tickets for sandbox account #{account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}")
  end
end



