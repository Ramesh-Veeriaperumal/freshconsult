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
                                         :cc_email => Helpdesk::Ticket.default_cc_hash.merge(cc_emails: cc_emails, fwd_emails: fwd_emails),
                                         :created_at => params[:created_at],
                                         :account_id => account_id,
                                         :deleted => params[:deleted] || 0,
                                         :spam => params[:spam] || 0,
                                         :custom_field => params[:custom_field],
                                         :tag_names => params[:tag_names],
                                         :product_id => params[:product_id],
                                         :company_id => params[:company_id])
    test_ticket.build_ticket_body(:description => Faker::Lorem.paragraph)
    if params[:attachments]
      test_ticket.attachments.build(content: params[:attachments][:resource],
                                    description: params[:attachments][:description],
                                    account_id: test_ticket.account_id)
    end
    test_ticket.cloud_files = params[:cloud_files] if params[:cloud_files]

    if @account.link_tkts_enabled? && params[:display_ids].present?
      test_ticket.association_type = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:tracker]
      test_ticket.related_ticket_ids = params[:display_ids]
    elsif @account.parent_child_tkts_enabled? && params[:assoc_parent_id].present?
      test_ticket.association_type = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:child]
      test_ticket.assoc_parent_tkt_id = params[:assoc_parent_id]
    end
    if @account.shared_ownership_enabled?
      test_ticket.internal_agent_id = params[:internal_agent_id] if params[:internal_agent_id]
      test_ticket.internal_group_id = internal_group ? internal_group.id : nil
    end
    test_ticket.group_id = group ? group.id : nil
    test_ticket.save_ticket
    test_ticket
  end

  def create_n_tickets(count, params={})
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
end
