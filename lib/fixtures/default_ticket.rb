class Fixtures::DefaultTicket

  attr_accessor :account, :ticket, :requester, :description, :description_html, :source, :type, :meta_data

  def create
    #Step 1 Ticket creation
    create_ticket
    #Step 2 Replying ticket
    create_reply
    #Step 3 Hook for child classes to do some after create stuff
    after_create
    ticket
  end

  private

    def create_ticket
      @ticket = Helpdesk::Ticket.seed(:account_id, :subject) do |s|
        s.account_id  = account.id
        s.subject     = I18n.t("default.ticket.#{source_name}.subject")
        s.email       = requester.email
        s.status      = Helpdesk::Ticketfields::TicketStatus::OPEN
        s.source      = source
        s.priority    = priority
        s.ticket_type = type
        s.status      = status
        s.disable_observer_rule   = true
        s.ticket_body_attributes  = {:description => description, :description_html => description_html }
        s.disable_activities      = true
        s.meta_data   = meta_data
        s.created_at  = created_at
        s.updated_at  = updated_at
      end

      #Activity gets called at the end of commit transaction(Whole seed transaction.) Hence added here explicitly.
      ticket.create_activity(requester, "activities.tickets.new_ticket.long", {}, "activities.tickets.new_ticket.short")
      ticket
    end


    def account
      @account ||= Account.current
    end

    def requester
      @requester ||= User.seed(:account_id, :email) do |s|
        s.account_id = account.id
        s.email      = Helpdesk::DEFAULT_TICKET_PROPERTIES["#{source_name}_ticket".to_sym][:email]
        s.name       = Helpdesk::DEFAULT_TICKET_PROPERTIES["#{source_name}_ticket".to_sym][:name]
      end
    end

    def agent
      @agent = User.find_by_email_and_account_id(Helpdesk::AGENT[:email],account.id)
      return @agent if @agent
      @agent = User.seed(:account_id, :email) do |s|
        s.account_id  = account.id
        s.email       = Helpdesk::AGENT[:email]
        s.name        = Helpdesk::AGENT[:name]
      end

      args = { 
        :role_ids => account.roles.agent.first.id, 
        :occasional => true,
        :deleted => true }
      @agent.make_agent(args)
      @agent
    end

    def priority
      TicketConstants::PRIORITY_KEYS_BY_TOKEN[:high]
    end

    def status
      Helpdesk::TicketStatus::OPEN
    end

    def description_html
      @description_html ||= I18n.t("default.ticket.#{source_name}.body")
    end

    def description
      @description ||= Helpdesk::HTMLSanitizer.html_to_plain_text(description_html)
    end

    def source_name
      Account.current.helpdesk_sources.default_ticket_source_names_by_key[source]
    end

    def updated_at
      created_at
    end

    def create_reply
      reply_note = ticket.notes.new(
        :user_id      => agent.id,
        :source       => Account.current.helpdesk_sources.note_source_keys_by_token["email"],
        :private      => false,
        :note_body_attributes  => {:body_html => note_body_html},
        :skip_notification     => true,
        :disable_observer_rule => true
        )

      reply_note.notable.disable_observer_rule = true
      reply_note.save_note! 
    end

    def note_body_html
      I18n.t("default.ticket.#{source_name}.reply")
    end

    def after_create
      # Hook for child classes
    end
end