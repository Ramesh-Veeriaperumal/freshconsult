class Fixtures::DefaultTickets

  attr_accessor :account, :ticket, :requester, :description, :description_html, :source, :type, :meta_data, 
    :tickets_content, :default_ticket_data, :industry

  PRE_ENRICHMENT_INDUSTRY = "base_tickets"  

  def initialize(industry)

    # Subject, Description, Reply content (which needs translation) from en.yml
    # Ticket properties from default_data.yml
    @industry = industry
    @tickets_content = I18n.t("fixtures.sample_tickets.#{industry}").map(&:with_indifferent_access)
    @default_ticket_data = DEFAULT_TICKET_DATA["#{industry}"]
    initialize_created_at
  end

  def generate
    default_ticket_data.each_with_index do | data ,i |
      create_ticket(data,i)
      create_reply(data,i) if data["replies"]
      if data['service_task']
        data['service_task'].each_with_index do |service_task_data, index|
          create_service_task(service_task_data, index, i)
        end
      end
      create_survey if data["survey"]
    end
  end

  private

  def create_ticket(ticket,ind)
    ticket_requester = create_user(ticket["requester"]["info"])
    create_company(ticket["requester"]["company"]) if ticket["requester"]["company"]

    @ticket = account.tickets.create(
      subject: tickets_content[ind][:subject],
      email: ticket_requester.email,
      status: account.ticket_statuses.find_by_name(ticket["status"].to_sym).status_id,
      source: Helpdesk::Source.default_ticket_source_keys_by_token[ticket["source"].to_sym],
      priority:  TicketConstants::PRIORITY_KEYS_BY_TOKEN[ticket["priority"].to_sym],
      group: ticket_group(ticket["group"]),
      ticket_type: ticket_type(ticket["type"]),
      disable_observer_rule: true,
      ticket_body_attributes: {description: description(tickets_content[ind]["description"]), description_html: tickets_content[ind]["description"]},
      disable_activities: true,
      created_at: created_at
      )
    @ticket.responder_id = agent.id if ticket["responder"]
    @ticket.tag_names=ticket["tags"]
    create_attachments(@ticket,ticket["attachment"]) if ticket["attachment"]
      # #Activity gets called at the end of commit transaction(Whole seed transaction.) Hence added here explicitly.
    @ticket.create_activity(requester, "activities.tickets.new_ticket.long", {}, "activities.tickets.new_ticket.short")
    @ticket
  end

  def create_service_task(ticket_data, index, parent_index)
    created_time = created_at
    requester = account.agents.first.user.make_current
    apt_start_time = create_appointment_start_time(created_time, ticket_data)
    apt_end_time = create_appointment_end_time(created_time, ticket_data)
    service_task = account.tickets.create(
      association_type: TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:child],
      assoc_parent_tkt_id: @ticket.display_id,
      email: requester.email,
      subject: tickets_content[parent_index]['service_tasks'][index]['subject'],
      status: account.ticket_statuses.find_by_name(ticket_data['status'].to_sym).status_id,
      priority: TicketConstants::PRIORITY_KEYS_BY_TOKEN[ticket_data['priority'].to_sym],
      group: ticket_group(ticket_data['group'], GroupType.group_type_id(GroupConstants::FIELD_GROUP_NAME)),
      ticket_type: ticket_type(ticket_data['type']),
      disable_observer_rule: true,
      ticket_body_attributes: {
        description: description(tickets_content[parent_index]['service_tasks'][index]['description']),
        description_html: tickets_content[parent_index]['service_tasks'][index]['description']
      },
      custom_field: {
        "cf_fsm_contact_name_#{account.id}" => ticket_data['contact']['name'],
        "cf_fsm_phone_number_#{account.id}" => ticket_data['contact']['phone_number'],
        "cf_fsm_service_location_#{account.id}" => ticket_data['contact']['service_location'],
        "cf_fsm_appointment_start_time_#{account.id}" => apt_start_time,
        "cf_fsm_appointment_end_time_#{account.id}" => apt_end_time
      },
      disable_activities: true,
      created_at: created_time
    )
    User.reset_current_user
    service_task
  end

  def create_appointment_start_time(created_time, ticket_data)
    (created_time + ticket_data['appointment_start_time']['day'].days).change(hour: ticket_data['appointment_start_time']['hour'], min: ticket_data['appointment_start_time']['minute'])
  end

  def create_appointment_end_time(created_time, ticket_data)
    (created_time + ticket_data['appointment_end_time']['day'].days).change(hour: ticket_data['appointment_end_time']['hour'], min: ticket_data['appointment_end_time']['minute'])
  end

    def description(desc_html)
      Helpdesk::HTMLSanitizer.html_to_plain_text(desc_html)
    end

    def create_attachments(obj,attachment)
      file_to_upload = File.new(Rails.root + attachment["file"])
      file = ActionDispatch::Http::UploadedFile.new(tempfile: file_to_upload, filename: File.basename(file_to_upload), type: attachment["type"])
      attach = obj.attachments.new(content: file)
      attach.save!
    end

    def ticket_type(type_value)
      picklist_values = account.ticket_fields.find_by_name("ticket_type").picklist_values
      type = picklist_values.find_by_value(type_value)
      return type.value if type
      picklist_values.create(:value => type_value).value
    end

  def ticket_group(group_name, group_type_name = GroupConstants::SUPPORT_GROUP_NAME)
      return nil if group_name.nil?
      groups = account.groups
      group = groups.find_by_name(group_name)
      return group if group
      groups.create(name: group_name, description: group_name, group_type: GroupType.group_type_id(group_type_name))
  end

    def account
      @account ||= Account.current
    end

    def create_user(user)
      @requester = account.users.find_by_email(user["email"])
      return @requester if @requester

      @requester = account.users.create(user)
    end

    def create_company(company_data)
      existing_company = account.companies.find_by_name(company_data["name"])
      if existing_company.nil?
        company = account.companies.create(company_data)
      end
      @requester.user_companies.create(:company_id => company.id)
    end

    def agent
      @agent = User.find_by_email_and_account_id(Helpdesk::AGENT[:email],account.id)
      return @agent if @agent
      @agent = account.users.create(
        :email       => Helpdesk::AGENT[:email],
        :name        => Helpdesk::AGENT[:name]
      )

      args = { 
        :role_ids => account.roles.agent.first.id, 
        :occasional => true,
        :deleted => true }
      @agent.make_agent(args)
      @agent
    end

    def create_reply(reply_data,ind)
      reply_data["replies"].each do | reply | 
        reply_note = ticket.notes.new(
          :user_id      => reply["requester"]? @requester.id : agent.id,
          :source       => Account.current.helpdesk_sources.note_source_keys_by_token["email"],
          :private      => false,
          :note_body_attributes  => {:body_html => tickets_content[ind]["replies"][reply["content"]]},
          :skip_notification     => true,
          :disable_observer_rule => true,
          :created_at => created_at
          )

        reply_note.notable.disable_observer_rule = true
        reply_note.save_note! 
        create_attachments(reply_note,reply["attachment"]) if reply["attachment"]
      end
    end

    def create_survey
      # Hook for child classes
            #current_user is reset so that survey goes from customer.
      current_user = User.current
      User.reset_current_user

      survey = account.custom_surveys.default.first

      survey_handle = ticket.custom_survey_handles.build(
        :survey => survey,
        :sent_while => CustomSurvey::Survey::CLOSED_NOTIFICATION
      )

      survey_handle.record_survey_result  CustomSurvey::Survey::CUSTOMER_RATINGS_BY_TOKEN["extremely_happy"]

      current_user.make_current
    end

    def initialize_created_at
      @created_at = account.created_at - 1.hour 
    end

    def created_at
      return account.created_at if industry == PRE_ENRICHMENT_INDUSTRY
      @created_at = @created_at + 3.minutes
    end

end