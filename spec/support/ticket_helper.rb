module TicketHelper
  def create_ticket(params = {}, group = nil, internal_group = nil)
    requester_id = params[:requester_id] # || User.find_by_email("rachel@freshdesk.com").id
    unless requester_id
      user = add_new_user(@account)
      requester_id = user.id
      user.user_companies.create(company_id: params[:company_id], default: true) if params[:company_id]
    end
    cc_emails = params[:cc_emails] || []
    fwd_emails = params[:fwd_emails] || []
    subject = params[:subject] || Faker::Lorem.words(10).join(' ')
    account_id =  group ? group.account_id : @account.id
    test_ticket = FactoryGirl.build(:ticket, :status => params[:status] || 2,
                                         :display_id => params[:display_id], 
                                         :requester_id =>  requester_id,
                                         :subject => subject,
                                         :priority => params[:priority] || 1,
                                         :responder_id => params[:responder_id],
                                         :source => params[:source] || 2,
                                         :ticket_type => params[:type],
                                         :cc_email => Helpdesk::Ticket.default_cc_hash.merge(cc_emails: cc_emails, fwd_emails: fwd_emails),
                                         :created_at => params[:created_at],
                                         :account_id => account_id,
                                         :deleted => params[:deleted] || 0,
                                         :spam => params[:spam] || 0,
                                         :custom_field => params[:custom_field],
                                         :tag_names => params[:tag_names],
                                         :product_id => params[:product_id],
                                         :sl_skill_id => params[:skill_id],
                                         :company_id => params[:company_id],
                                         :import_id => params[:import_id],
                                         :ticket_type => params[:type] || "Question",
                                         :email_config_id => params[:email_config_id],
                                         channel_id: params[:channel_id],
                                         channel_profile_unique_id: params[:profile_unique_id],
                                         channel_message_id: params[:channel_message_id])
    test_ticket.build_ticket_body(:description => params[:description] || Faker::Lorem.paragraph)
    if params[:attachments]
      attachment_params = params[:attachments].is_a?(Array) ? params[:attachments] : [params[:attachments]]
      attachment_params.each do |attach|
        test_ticket.attachments.build(content: attach[:resource],
                                      description: attach[:description],
                                      account_id: test_ticket.account_id)
      end
    end
    test_ticket.cloud_files = params[:cloud_files] if params[:cloud_files]
    test_ticket.sender_email = params[:sender_email] if params[:sender_email].present?


    if @account.link_tickets_enabled? && params[:display_ids].present?
      test_ticket.association_type = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:tracker]
      test_ticket.related_ticket_ids = params[:display_ids]
    elsif (@account.parent_child_tickets_enabled? || @account.field_service_management_enabled?) && params[:assoc_parent_id].present?
      test_ticket.association_type = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:child]
      test_ticket.assoc_parent_tkt_id = params[:assoc_parent_id]
    end
    if @account.shared_ownership_enabled?
      test_ticket.internal_agent_id = params[:internal_agent_id] if params[:internal_agent_id]
      test_ticket.internal_group_id = internal_group ? internal_group.id : nil
    end
    test_ticket.group_id = group ? group.id : nil
    test_ticket.skip_sbrr_assigner = params[:skip_sbrr_assigner] if params[:skip_sbrr_assigner]
    test_ticket.skill = params[:skill] if params[:skill]
    test_ticket.save_ticket
    test_ticket
  end

  def create_service_task_ticket(options = {})
    parent_ticket_id = options[:assoc_parent_id].present? ? options[:assoc_parent_id] : create_ticket.display_id

    fsm_fields = [ :fsm_contact_name, :fsm_phone_number, :fsm_service_location, :fsm_appointment_start_time, :fsm_appointment_end_time ]
    fsm_custom_fields = Hash[options.select { |key,_| fsm_fields.include? key }.map { |k,v| ["cf_#{k}_#{Account.current.id}", v] }]
    params = { assoc_parent_id: parent_ticket_id, email: Faker::Internet.email,
               responder_id: options[:responder_id],
               description: Faker::Lorem.characters(10), subject: Faker::Lorem.characters(10),
               priority: options[:priority] || 2, status: options[:status] || 2, type: Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE,
               custom_field: fsm_custom_fields }
    fsm_ticket = create_ticket(params)
    fsm_ticket
  end

  def create_n_tickets(count, params = {})
    ticket_ids = []
    count.times do
      ticket_ids << create_ticket(params).display_id
    end
    ticket_ids
  end

  def ticket_incremented?(ticket_size)
    @account.reload
    @account.tickets.size.should eql ticket_size + 1
  end

  def create_test_time_entry(params = {}, test_ticket = nil)
    ticket = test_ticket.blank? ? create_ticket : test_ticket
    time_sheet = FactoryGirl.build(:time_sheet, user_id: params[:agent_id] || @agent.id,
                                   workable_id: ticket.id,
                                   account_id: @account.id,
                                   billable: params[:billable] || 1,
                                   note: Faker::Lorem.sentence(3))
    time_sheet.save
    time_sheet
  end

  def create_field_agent
    add_test_agent(@account, { role: Role.find_by_name('Agent').id, agent_type: AgentType.agent_type_id(Agent::FIELD_AGENT), ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets]})
  end

  def create_field_agent_group
    group = create_group(@account, { name: Faker::Lorem.characters(10), description: Faker::Lorem.paragraph, group_type:
                                     GroupType.group_type_id(GroupConstants::FIELD_GROUP_NAME)})
  end

  def add_watchers_to_ticket(account, options={})
    account = account || @account
    agent_ids = options[:agent_id]
    agent_ids.each do |agent_id|
      ticket_watcher = FactoryGirl.build(:subscription, account_id: account.id,
                                         ticket_id: options[:ticket_id],
                                         user_id: agent_id)
      ticket_watcher.save!
    end
  end

  def create_ticket_with_multiple_attachments(params = {})
    attachments = []
    params[:num_of_files].times do
      file = File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))
      attachments << { resource: file }
    end
    create_ticket(params.merge(attachments: attachments))
  end
end
