['ticket_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

module CoreTicketsTestHelper
  include CoreTicketFieldsTestHelper


  XSS_SCRIPT_TEXT = "<script> alert('hi'); </script>"
  CUSTOM_FIELDS_TYPES = %w(text paragraph checkbox decimal number)
  CUSTOM_FIELDS_CONTENT_BY_TYPE = { 'text' => XSS_SCRIPT_TEXT, 'paragraph' =>  XSS_SCRIPT_TEXT,
        'checkbox' => true, 'decimal' => 1.1, 'number' => 1 }


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
                    :assoc_parent_id => params[:assoc_parent_id] || "",
                    :cc_emails => params[:cc_emails] || []
                  }
  end

  def enable_adv_ticketing(features = [], &block)
    features.is_a?(Array) ? features.each { |f| Account.current.add_feature(f) } : Account.current.add_feature(features)
    if block_given?
      yield
      disable_adv_ticketing(features)
    end
  end

  def disable_adv_ticketing(features = [])
    features.is_a?(Array) ? features.each { |f| Account.current.revoke_feature(f) } : Account.current.revoke_feature(features)
  end

  def create_ticket(params = {}, group = nil, internal_group = nil)
    group ||= @account.groups.find_by_id(params[:group_id]) if params.key?(:group_id)
    internal_group ||= @account.groups.find_by_id(params[:internal_group_id]) if params.key?(:internal_group_id)
    requester_id = params[:requester_id] #|| User.find_by_email("rachel@freshdesk.com").id
    unless requester_id
      user = add_new_user(@account)
      requester_id = user.id
    end
    cc_emails = params[:cc_emails] || []
    fwd_emails = params[:fwd_emails] || []
    subject = params[:subject] || Faker::Lorem.words(10).join(" ")
    account_id = group ? group.account_id : @account.id
    test_ticket = FactoryGirl.build(:ticket, :status => params[:status] || 2,
                                         :display_id => params[:display_id],
                                         :requester_id =>  requester_id,
                                         :subject => subject,
                                         :responder_id => params[:responder_id],
                                         :source => params[:source] || 2,
                                         :priority => params[:priority] || 2,
                                         :product_id => params[:product_id],
                                         :ticket_type => params[:ticket_type],
                                         :to_email => params[:to_email],
                                         :cc_email => Helpdesk::Ticket.default_cc_hash.merge(cc_emails: cc_emails, 
                                                        fwd_emails: fwd_emails, tkt_cc: cc_emails),
                                         :created_at => params[:created_at],
                                         :account_id => account_id,
                                         :custom_field => params[:custom_field],
                                         :to_emails => params[:to_emails],
                                         channel_id: params[:channel_id],
                                         channel_profile_unique_id: params[:profile_unique_id],
                                         channel_message_id: params[:channel_message_id]
                                       )
    test_ticket.sender_email = params[:sender_email] if params[:sender_email].present?
    test_ticket.tag_ids = params[:tag_ids] if params.key?(:tag_ids)
    test_ticket.build_ticket_body(:description => params[:description] || Faker::Lorem.paragraph)
    if params[:attachments]
      params[:attachments].each do |attach|
        test_ticket.attachments.build(:content => attach[:resource],
                                      :description => attach[:description],
                                      :account_id => test_ticket.account_id)
      end
    end

    if @account.link_tickets_enabled? && params[:display_ids].present?
      test_ticket.association_type = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:tracker]
      test_ticket.related_ticket_ids = params[:display_ids]
    elsif @account.parent_child_tickets_enabled? and params[:assoc_parent_id].present?
      test_ticket.association_type = TicketConstants::TICKET_ASSOCIATION_KEYS_BY_TOKEN[:child]
      test_ticket.assoc_parent_tkt_id = params[:assoc_parent_id]
    end
    if @account.shared_ownership_enabled?
      test_ticket.internal_agent_id = params[:internal_agent_id] if params[:internal_agent_id]
      test_ticket.internal_group_id = internal_group ? internal_group.id : nil
    end
    test_ticket.group_id = group ? group.id : nil
    test_ticket.save_ticket
    test_ticket.reload if test_ticket.id
    test_ticket
  end

  def create_link_tickets(related_tickets_count=5, tracker_subject = nil, subjects=[])
    related_ticket_ids = related_tickets_count.times.collect { |i| create_ticket(:subject => subjects[i]).display_id }
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

  def create_ticket_with_attachments(params={})
    file = File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))
    attachments = [{:resource => file}]
    create_ticket(params.merge({:attachments => attachments}))
  end

  def create_parent_ticket(params={})
    parent_child_tickets(params, true)
  end

  def create_child_ticket(params={})
    parent_child_tickets(params)
  end

  def parent_child_tickets params={}, is_parent = false
    prt_ticket = create_ticket(params)
    @agent.make_current
    options = {:requester_id => @agent.id, :assoc_parent_id => prt_ticket.display_id, :subject => "#{params[:subject]}_child_tkt"}
    tkt = (is_parent ? prt_ticket : child_tkt) if (child_tkt = create_ticket(params.merge(options))).present?
  end

  def create_multiple_pc_tickets (child_tickets_count=5, parent_subject = nil, subjects=[])
    @agent.make_current
    prt_ticket = create_ticket({:subject => parent_subject})
    Sidekiq::Testing.inline! do
      @child_ticket_ids = child_tickets_count.times.collect  {|i|
        create_ticket({:subject => subjects[i], :assoc_parent_id => prt_ticket.display_id}).display_id }
    end
    @child_ticket_ids
  end

  def update_bulk_tickets(tickets_display_id = [], params = {})
    put :update_multiple, {:helpdesk_note => {:note_body_attributes => {:body_html => ""},
                                              :private => "0",
                                              :user_id => @agent.id,
                                              :source => "0"
    },
                           :helpdesk_ticket => {
                             :internal_group_id => params[:internal_group_id],
                             :internal_agent_id => params[:internal_agent_id],
                             :status => params[:status_id]
                           },
                           :ids => tickets_display_id
    }
  end

  def custom_search_on_ticket_list_filters(conditions = [], agent_mode = 0, group_mode = 0)
    post :custom_search, { :data_hash => conditions, :agent_mode => agent_mode, :group_mode => group_mode,
                           :filter_name => "all_tickets" }
  end

  def create_ticket_with_xss other_object_params = {}
    params = create_ticket_params_with_xss other_object_params
    ticket = create_ticket params
  end

  def create_ticket_params_with_xss other_object_params
    ticket_params_hash = {}
    ticket_params_hash[:subject] = XSS_SCRIPT_TEXT
    params = ticket_params_hash.except(:description).merge(custom_field: {})
    CUSTOM_FIELDS_TYPES.each do |field_type|
      custom_field = create_custom_field("test_custom_#{field_type}", field_type)
      Account.current.reload
      params[:custom_field][:"#{custom_field.name}"] = CUSTOM_FIELDS_CONTENT_BY_TYPE[field_type]
    end
    params.merge(other_object_params)
  end

end
