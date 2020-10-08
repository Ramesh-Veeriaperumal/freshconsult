['ticket_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

module TicketsTestHelper
  include CoreTicketFieldsTestHelper
  include TicketsNotesHelper
  include BusinessHoursCalculation

  MAX_DESC_LIMIT = 10000

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

  def create_ticket_with_attachments(params={})
    file = File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))
    attachments = [{:resource => file}]
    create_ticket(params.merge({:attachments => attachments}))
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
    account_id = group ? group.account_id : @account.id
    test_ticket = FactoryGirl.build(:ticket, :status => params[:status] || 2,
                                         :display_id => params[:display_id],
                                         :requester_id =>  requester_id,
                                         :subject => subject,
                                         :responder_id => params[:responder_id],
                                         :source => params[:source] || 2,
                                         :priority => params[:priority] || 2,
                                         :ticket_type => params[:ticket_type],
                                         :cc_email => Helpdesk::Ticket.default_cc_hash.merge(cc_emails: cc_emails, fwd_emails: fwd_emails),
                                         :created_at => params[:created_at],
                                         :account_id => account_id,
                                         :sl_skill_id => params[:skill_id],
                                         :custom_field => params[:custom_field])
    test_ticket.build_ticket_body(:description => Faker::Lorem.paragraph)
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

  def cp_ticket_event_info_pattern(ticket, expected_hash)
    # TODO: Testing lifecycle_hash.
    lifecycle_hash = {}
    activity_type = ticket.activity_type
    activity_type_hash = if activity_type
                           case activity_type[:type]
                           when Helpdesk::Ticket::SPLIT_TICKET_ACTIVITY
                             split_ticket_hash(activity_type)
                           when Helpdesk::Ticket::MERGE_TICKET_ACTIVITY
                             merge_ticket_hash(activity_type)
                           when Social::Constants::TWITTER_FEED_TICKET
                             social_tab_ticket_hash(activity_type)
                           when Helpdesk::Ticket::ROUND_ROBIN_ACTIVITY
                             round_robin_hash(activity_type)
                           else
                             {}
                           end
                         else
                           {}
                         end
    {
      action_in_bhrs: action_in_bhrs?(ticket),
      pod: ChannelFrameworkConfig['pod'],
      hypertrail_version: CentralConstants::HYPERTRAIL_VERSION
    }.merge(lifecycle_hash).merge(activity_type_hash).merge(expected_hash)
  end

  def split_ticket_hash(activity_type)
    {
      activity_type: {
        type: Helpdesk::Ticket::SPLIT_TICKET_ACTIVITY,
        source_ticket_id: activity_type[:source_ticket_id],
        source_note_id: activity_type[:source_note_id]
      }
    }
  end

  def merge_ticket_hash(activity_type)
    {
      activity_type: {
        type: Helpdesk::Ticket::MERGE_TICKET_ACTIVITY,
        source_ticket_id: activity_type[:source_ticket_id],
        target_ticket_id: activity_type[:target_ticket_id]
      }
    }
  end

  def social_tab_ticket_hash(activity_type)
    {
      activity_type: {
        type: Social::Constants::TWITTER_FEED_TICKET
      }
    }
  end

  def round_robin_hash(activity_type)
    {
      activity_type: activity_type
    }
  end

  def action_in_bhrs?(ticket)
    BusinessCalendar.execute(ticket) do
      action_occured_in_bhrs?(Time.zone.now, ticket.group)
    end
  end

  def cp_ticket_pattern(expected_output = {}, ticket)
    ret_hash = {
      id: ticket.id,
      display_id: ticket.display_id,
      account_id: ticket.account_id,
      responder_id: ticket.responder_id,
      group_id: ticket.group_id,
      status: { id: ticket.status, name: ticket.status_name },
      priority: { id: ticket.priority, name: TicketConstants::PRIORITY_NAMES_BY_KEY[ticket.priority] },
      ticket_type: ticket.ticket_type,
      source: { id: ticket.source, name: Account.current.ticket_source_revamp_enabled? ? ticket.source_name : Account.current.helpdesk_sources.default_ticket_source_names_by_key[ticket.source] },
      requester_id: ticket.requester_id,
      due_by: ticket.due_by.try(:utc).try(:iso8601),
      created_at: ticket.created_at.try(:utc).try(:iso8601),
      closed_at: ticket.closed_at.try(:utc).try(:iso8601),
      custom_fields: ticket.central_custom_fields_hash,
      company_id: ticket.company_id,
      sla_policy_id: ticket.sla_policy_id,
      is_escalated: ticket.isescalated,
      fr_escalated: ticket.fr_escalated,
      resolution_escalation_level: ticket.escalation_level,
      response_reminded: ticket.sla_response_reminded,
      resolution_reminded: ticket.sla_resolution_reminded,
      resolved_at: ticket.resolved_at.try(:utc).try(:iso8601),
      time_to_resolution_in_bhrs: ticket.resolution_time_by_bhrs,
      time_to_resolution_in_chrs: ticket.resolution_time_by_chrs,
      inbound_count: ticket.inbound_count,
      first_response_by_bhrs: ticket.first_resp_time_by_bhrs,
      first_assign_by_bhrs: ticket.reports_hash['first_assign_by_bhrs'],
      first_response_id: ticket.reports_hash['first_response_id'],
      agent_reassigned_count: ticket.reports_hash['agent_reassigned_count'],
      group_reassigned_count: ticket.reports_hash['group_reassigned_count'],
      reopened_count: ticket.reports_hash['reopened_count'],
      private_note_count: ticket.reports_hash['private_note_count'],
      public_note_count: ticket.reports_hash['public_note_count'],
      agent_reply_count: ticket.reports_hash['agent_reply_count'],
      customer_reply_count: ticket.reports_hash['customer_reply_count'],
      reopened_count: ticket.reports_hash['reopened_count'],
      agent_assigned_flag: ticket.reports_hash['agent_assigned_flag'],
      agent_reassigned_flag: ticket.reports_hash['agent_reassigned_flag'],
      group_assigned_flag: ticket.reports_hash['group_assigned_flag'],
      group_reassigned_flag: ticket.reports_hash['group_reassigned_flag'],
      internal_agent_assigned_flag: ticket.reports_hash['internal_agent_assigned_flag'],
      internal_agent_reassigned_flag: ticket.reports_hash['internal_agent_reassigned_flag'],
      internal_group_assigned_flag: ticket.reports_hash['internal_group_assigned_flag'],
      internal_group_reassigned_flag: ticket.reports_hash['internal_group_reassigned_flag'],
      internal_agent_first_assign_in_bhrs: ticket.reports_hash['internal_agent_first_assign_in_bhrs'],
      last_resolved_at: ticket.reports_hash['last_resolved_at'],
      updated_at: ticket.updated_at.try(:utc).try(:iso8601),
      parent_id: ticket.parent_ticket,
      outbound_email: ticket.outbound_email?,
      subject: ticket.subject,
      description_text: ticket.description,
      description_html: ticket.description_html,
      watchers: ticket.watchers,
      urgent: ticket.urgent,
      spam: ticket.spam,
      trained: ticket.trained,
      fr_due_by: ticket.frDueBy.try(:utc).try(:iso8601),
      to_emails: ticket.to_emails,
      cc_emails: ticket.cc_email[:cc_emails],
      fwd_emails: ticket.cc_email[:fwd_emails],
      bcc_emails: ticket.cc_email[:bcc_emails],
      reply_cc: ticket.cc_email[:reply_cc],
      tkt_cc: ticket.cc_email[:tkt_cc],
      email_config_id: ticket.email_config_id,
      deleted:ticket.deleted,
      group_users: Array,
      tags: Array,
      import_id: ticket.import_id,
      attachment_ids: ticket.attachments.map(&:id),
      first_response_agent_id: ticket.reports_hash['first_response_agent_id'],
      first_response_group_id: ticket.reports_hash['first_response_group_id'],
      first_assign_agent_id: ticket.reports_hash['first_assign_agent_id'],
      first_assign_group_id: ticket.reports_hash['first_assign_group_id'],
      first_assigned_at: ticket.first_assigned_at.try(:utc).try(:iso8601),
      first_response_time: ticket.first_response_time.try(:utc).try(:iso8601),
      product_id: ticket.product_id,
      archive: ticket.archive,
      internal_agent_id: ticket.internal_agent_id,
      internal_group_id: ticket.internal_group_id,
      on_state_time: ticket.on_state_time,
      associates: render_assoc_hash(ticket.association_type),
      associates_rdb: ticket.associates_rdb,
      source_additional_info: source_additional_info_hash(ticket),
      status_stop_sla_timer: ticket.status_stop_sla_timer,
      status_deleted: ticket.status_deleted,
      requester_responded_at: ticket.requester_responded_at,
      agent_responded_at: ticket.agent_responded_at
    }
    ret_hash[:skill_id] = ticket.sl_skill_id if Account.current.skill_based_round_robin_enabled?
    if Account.current.next_response_sla_enabled?
      ret_hash[:nr_due_by] = ticket.nr_due_by.try(:utc).try(:iso8601)
      ret_hash[:nr_escalated] = ticket.nr_escalated
      ret_hash[:next_response_reminded] = ticket.nr_reminded
    end
    ret_hash
  end

  def preload_cp_ticket_pattern(ticket)
    ret_hash = {
      id: ticket.id,
      display_id: ticket.display_id,
      account_id: ticket.account_id,
      responder_id: ticket.responder_id,
      group_id: ticket.group_id,
      status: { id: ticket.status, name: ticket.status_name },
      priority: { id: ticket.priority, name: TicketConstants::PRIORITY_NAMES_BY_KEY[ticket.priority] },
      ticket_type: ticket.ticket_type,
      source: { id: ticket.source, name: Account.current.ticket_source_revamp_enabled? ? ticket.source_name : Account.current.helpdesk_sources.default_ticket_source_names_by_key[ticket.source] },
      requester_id: ticket.requester_id,
      due_by: ticket.due_by.try(:utc).try(:iso8601),
      created_at: ticket.created_at.try(:utc).try(:iso8601),
      closed_at: ticket.closed_at.try(:utc).try(:iso8601),
      company_id: ticket.company_id,
      sla_policy_id: ticket.sla_policy_id,
      is_escalated: ticket.isescalated,
      fr_escalated: ticket.fr_escalated,
      resolution_escalation_level: ticket.escalation_level,
      response_reminded: ticket.sla_response_reminded,
      resolution_reminded: ticket.sla_resolution_reminded,
      resolved_at: ticket.resolved_at.try(:utc).try(:iso8601),
      time_to_resolution_in_bhrs: ticket.resolution_time_by_bhrs,
      time_to_resolution_in_chrs: ticket.resolution_time_by_chrs,
      inbound_count: ticket.inbound_count,
      first_response_by_bhrs: ticket.first_resp_time_by_bhrs,
      first_assign_by_bhrs: ticket.reports_hash['first_assign_by_bhrs'],
      first_response_id: ticket.reports_hash['first_response_id'],
      agent_reassigned_count: ticket.reports_hash['agent_reassigned_count'],
      group_reassigned_count: ticket.reports_hash['group_reassigned_count'],
      reopened_count: ticket.reports_hash['reopened_count'],
      private_note_count: ticket.reports_hash['private_note_count'],
      public_note_count: ticket.reports_hash['public_note_count'],
      agent_reply_count: ticket.reports_hash['agent_reply_count'],
      customer_reply_count: ticket.reports_hash['customer_reply_count'],
      agent_assigned_flag: ticket.reports_hash['agent_assigned_flag'],
      agent_reassigned_flag: ticket.reports_hash['agent_reassigned_flag'],
      group_assigned_flag: ticket.reports_hash['group_assigned_flag'],
      group_reassigned_flag: ticket.reports_hash['group_reassigned_flag'],
      internal_agent_assigned_flag: ticket.reports_hash['internal_agent_assigned_flag'],
      internal_agent_reassigned_flag: ticket.reports_hash['internal_agent_reassigned_flag'],
      internal_group_assigned_flag: ticket.reports_hash['internal_group_assigned_flag'],
      internal_group_reassigned_flag: ticket.reports_hash['internal_group_reassigned_flag'],
      internal_agent_first_assign_in_bhrs: ticket.reports_hash['internal_agent_first_assign_in_bhrs'],
      last_resolved_at: ticket.reports_hash['last_resolved_at'],
      updated_at: ticket.updated_at.try(:utc).try(:iso8601),
      outbound_email: ticket.outbound_email?,
      watchers: ticket.watchers,
      urgent: ticket.urgent,
      spam: ticket.spam,
      trained: ticket.trained,
      fr_due_by: ticket.frDueBy.try(:utc).try(:iso8601),
      to_emails: ticket.to_emails,
      cc_emails: ticket.cc_email[:cc_emails],
      fwd_emails: ticket.cc_email[:fwd_emails],
      bcc_emails: ticket.cc_email[:bcc_emails],
      reply_cc: ticket.cc_email[:reply_cc],
      tkt_cc: ticket.cc_email[:tkt_cc],
      email_config_id: ticket.email_config_id,
      deleted: ticket.deleted,
      group_users: Array,
      tags: Array,
      import_id: ticket.import_id,
      attachment_ids: ticket.attachments.map(&:id),
      first_response_agent_id: ticket.reports_hash['first_response_agent_id'],
      first_response_group_id: ticket.reports_hash['first_response_group_id'],
      first_assign_agent_id: ticket.reports_hash['first_assign_agent_id'],
      first_assign_group_id: ticket.reports_hash['first_assign_group_id'],
      first_assigned_at: ticket.first_assigned_at.try(:utc).try(:iso8601),
      first_response_time: ticket.first_response_time.try(:utc).try(:iso8601),
      product_id: ticket.product_id,
      archive: ticket.archive,
      internal_agent_id: ticket.internal_agent_id,
      internal_group_id: ticket.internal_group_id,
      on_state_time: ticket.on_state_time,
      source_additional_info: source_additional_info_hash(ticket),
      status_stop_sla_timer: ticket.status_stop_sla_timer,
      status_deleted: ticket.status_deleted
    }
    ret_hash[:skill_id] = ticket.sl_skill_id if Account.current.skill_based_round_robin_enabled?
    if Account.current.next_response_sla_enabled?
      ret_hash[:nr_due_by] = ticket.nr_due_by.try(:utc).try(:iso8601)
      ret_hash[:nr_escalated] = ticket.nr_escalated
      ret_hash[:next_response_reminded] = ticket.nr_reminded
    end
    ret_hash
  end

  def source_additional_info_hash(ticket)
    source_info = {}
    source_info[:email] = email_source_info(ticket.schema_less_ticket.header_info) if email_ticket?(ticket.source)
    tweet = ticket.try(:tweet)
    fb_post = ticket.try(:fb_post)

    if tweet && ticket.source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:twitter]
      twitter_handle = tweet.twitter_handle
      source_info = {
        twitter: {
          tweet_id: tweet.tweet_id.to_s,
          type: tweet.tweet_type,
          support_handle_id: twitter_handle.try(:twitter_user_id).try(:to_s),
          support_screen_name:  twitter_handle.try(:screen_name),
          requester_screen_name: ticket.requester.twitter_id,
          twitter_handle_id: twitter_handle.try(:id),
          stream_id: tweet.stream_id
        }
      }
    elsif fb_post
      fb_page = fb_post.facebook_page
      source_info = {
        facebook: {
          support_fb_page_id: fb_page.try(:page_id).try(:to_s),
          support_fb_page_name: fb_page.try(:page_name),
          fb_page_db_id: fb_page.try(:id).try(:to_s),
          requester_profile_id: ticket.requester.fb_profile_id,
          type: fb_post.msg_type,
          fb_item_id: fb_post.post_id.to_s
        }
      }
    end
    return source_info.presence
  end

  def email_ticket?(source)
    [Account.current.helpdesk_sources.ticket_source_keys_by_token[:email],
     Account.current.helpdesk_sources.ticket_source_keys_by_token[:chat]].include?(source)
  end

  def cp_assoc_ticket_pattern(expected_output = {}, ticket)
    assoc_ticket_pattern = {
      requester: Hash,
      responder: (ticket.responder ? Hash : nil),
      group: (ticket.group ? Hash : nil),
      attachments: Array,
      product: (ticket.product ? Hash : nil)
    }
    assoc_ticket_pattern[:skill] = (ticket.skill ? Hash : nil) if Account.current.skill_based_round_robin_enabled?
    return assoc_ticket_pattern.merge({ internal_agent: (ticket.internal_agent ? Hash : nil), internal_group: (ticket.internal_group ? Hash : nil) }) if Account.current.shared_ownership_enabled?

    assoc_ticket_pattern
  end

  def internal_agent_association_pattern(ticket)
    {
      id: ticket.internal_agent_id,
      name: ticket.internal_agent.name,
      type: ticket.internal_agent.agent_or_contact,
      email: ticket.internal_agent.email,
      account_id: ticket.account_id,
      active: ticket.internal_agent.active
    }
  end

  def internal_group_association_pattern(ticket)
    {
      id: ticket.internal_group_id,
      name: ticket.internal_group.name,
      account_id: ticket.account_id,
      group_type:
        {
          id: ticket.internal_group.group_type_hash[:id],
          name: ticket.internal_group.group_type_hash[:name]
        },
      business_calendar_id: ticket.internal_group.business_calendar_id
    }
  end

  def cp_ticket_destroy_pattern(expected_output = {}, ticket)
    {
      id: ticket.id,
      display_id: ticket.display_id,
      account_id: ticket.account_id,
      archive: false,
      ticket_type: ticket.ticket_type,
      source: { id: ticket.source, name: Account.current.ticket_source_revamp_enabled? ? ticket.source_name : Account.current.helpdesk_sources.default_ticket_source_names_by_key[ticket.source] }
    }
  end

  def cp_ticket_destroy_pattern_for_archive_action(expected_output = {}, ticket)
    {
      id: ticket.id,
      display_id: ticket.display_id,
      account_id: ticket.account_id,
      archive: true,
      ticket_type: ticket.ticket_type,
      source: { id: ticket.source, name: Account.current.ticket_source_revamp_enabled? ? ticket.source_name : Account.current.helpdesk_sources.default_ticket_source_names_by_key[ticket.source] }
    }
  end

  def render_assoc_hash(current_association_type)
    return nil if current_association_type.blank?

    {
      id: current_association_type,
      type: TicketConstants::TICKET_ASSOCIATION_TOKEN_BY_KEY[current_association_type]
    }
  end
  
  def skill_key_value_pairs(ticket)
    {
      id: ticket.skill.id,
      name: ticket.skill.name,
      account_id: ticket.skill.account_id
    }
  end
end
