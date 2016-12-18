module TicketsTestHelper

  def ticket_params_hash(params = {})
    description = params[:description] || Faker::Lorem.paragraph
    description_html = params[:description_html] || "<div>#{description}</div>"
    params_hash = { :helpdesk_ticket => { 
                      :email => params[:email] || Faker::Internet.email,
                      :subject => params[:subject] || Faker::Lorem.words(10).join(' '),
                      :ticket_type => params[:ticket_type] || "Question",
                      :source => params[:source] || 1,
                      :status => params[:status] || 3,
                      :priority => params[:priority] || 2,
                      :group_id => params[:group_id] || "",
                      :responder_id => params[:responder_id] || "",
                      :description => description,
                      :description_html => description_html,                        
                    },
                    :helpdesk => {
                      :tags => params[:tags] || ""
                    },
                    :display_ids => params[:display_ids] || "",
                    :cc_emails => params[:cc_emails] || ""
                  }
  end

  def enable_link_tickets
    Account.current.launch :link_tickets
    if block_given?
      yield
      Account.current.rollback :link_tickets
    end
  end

  def disable_link_tickets
    Account.current.rollback :link_tickets
  end

  def create_ticket(params = {}, group = nil, internal_group = nil)
    requester_id = params[:requester_id] #|| User.find_by_email("rachel@freshdesk.com").id
    unless requester_id
      user = add_new_user(@account)
      requester_id = user.id
    end
    cc_emails = params[:cc_emails] || []
    fwd_emails = params[:fwd_emails] || []
    subject = params[:subject] || Faker::Lorem.words(10).join(" ")
    account_id =  group ? group.account_id : @account.id
    test_ticket = FactoryGirl.build(:ticket, :status => params[:status] || 2,
                                         :display_id => params[:display_id], 
                                         :requester_id =>  requester_id,
                                         :subject => subject,
                                         :responder_id => params[:responder_id],
                                         :source => params[:source] || 2,
                                         :cc_email => Helpdesk::Ticket.default_cc_hash.merge(cc_emails: cc_emails, fwd_emails: fwd_emails),
                                         :created_at => params[:created_at],
                                         :account_id => account_id,
                                         :custom_field => params[:custom_field])
    test_ticket.build_ticket_body(:description => Faker::Lorem.paragraph)
    if params[:attachments]
      test_ticket.attachments.build(:content => params[:attachments][:resource], 
                                    :description => params[:attachments][:description], 
                                    :account_id => test_ticket.account_id)
    end

    if @account.link_tickets_enabled? && params[:display_ids].present?
      test_ticket.association_type = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:tracker]
      test_ticket.related_ticket_ids = params[:display_ids]
    end
    test_ticket.internal_agent_id = params[:internal_agent_id] if params[:internal_agent_id]
    test_ticket.group_id = group ? group.id : nil
    test_ticket.internal_group_id = internal_group ? internal_group.id : nil
    test_ticket.save_ticket
    test_ticket
  end

  def create_link_tickets(related_tickets_count=5, tracker_subject = nil, subjects=[])
    related_ticket_ids = related_tickets_count.times.collect  {|i| create_ticket(:subject => subjects[i]).display_id }
    Sidekiq::Testing.inline! do
      tracker = create_ticket({:subject => tracker_subject, :display_ids => related_ticket_ids})
    end
    related_ticket_ids
  end

  def create_tracker(tracker_params, params = {})
    ticket = create_ticket({:subject => params[:subject]})
    @agent.make_current
    options = {:requester_id => @agent.id, :display_ids => [ticket.display_id]}
    create_ticket(tracker_params.merge(options))
  end

  def link_to_tracker(tracker, display_ids)
    linked = []
    tickets = @account.tickets.where(:display_id => display_ids)
    tickets.each do |t|
      if t.can_be_associated?
        t.associates = [tracker.display_id]
        t.update_attributes(
          :association_type => TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:related],
          :associates_rdb => tracker.display_id)
        linked << t.display_id
      end
    end
    tracker.add_associates(linked)
  end
end