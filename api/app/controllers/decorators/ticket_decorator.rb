class TicketDecorator < ApiDecorator
  include TicketPropertiesSuggester::Util
  include Crypto::TokenHashing
  include AdvancedTicketScopes

  delegate :ticket_body, :custom_field_via_mapping, :cc_email, :email_config_id,
           :fr_escalated, :group_id, :priority, :requester_id, :responder, :responder_id,
           :source, :spam, :status, :subject, :display_id, :ticket_type, :schema_less_ticket,
           :deleted, :due_by, :frDueBy, :isescalated, :description, :internal_group_id,
           :internal_agent_id, :association_type, :associates, :associated_ticket?,
           :can_be_associated?, :description_html, :tag_names, :attachments,
           :attachments_sharable, :company_id, :cloud_files, :ticket_states, :skill_id,
           :subsidiary_tkts_count, :import_id, :id, :nr_escalated, :nr_due_by, :tweet_type, :fb_msg_type, to: :record

  delegate :multiple_user_companies_enabled?, to: 'Account.current'

  DIRTY_FIX_MAPPING = {
    resolved_at: [Helpdesk::Ticketfields::TicketStatus::RESOLVED, Helpdesk::Ticketfields::TicketStatus::CLOSED],
    closed_at: [Helpdesk::Ticketfields::TicketStatus::CLOSED],
    pending_since: [Helpdesk::Ticketfields::TicketStatus::PENDING]
  }.freeze

  TICKET_TYPE = 'ticket'.freeze

  def initialize(record, options)
    super(record)
    @name_mapping = options[:name_mapping]
    @contact_name_mapping = options[:contact_name_mapping]
    @company_name_mapping = options[:company_name_mapping]
    @permission = options[:permission]
    @permissibles = options[:permissibles]
    @last_broadcast_message = options[:last_broadcast_message]
    @sideload_options = options[:sideload_options] || []
    @discard_options = options[:discard_options] || []
    @custom_fields_mapping = options[:custom_fields_mapping] || {}
  end

  def custom_fields
    custom_fields_hash = {}
    custom_field_via_mapping.each do |k, v|
      next if @custom_fields_mapping[k] == Helpdesk::TicketField::CUSTOM_FILE && !private_api?

      if @custom_fields_mapping[k] == TicketFieldsConstants::SECURE_TEXT
        custom_fields_hash[TicketDecorator.display_name(k)] = v if display_secure_text_data(k, v.to_i)
        next
      end

      custom_fields_hash[@name_mapping[k]] = if v.respond_to?(:utc)
                                               if @custom_fields_mapping[k] == Helpdesk::TicketField::CUSTOM_DATE_TIME
                                                 format_date(v, true)
                                               else
                                                 format_date(v)
                                               end
                                             elsif @custom_fields_mapping[k] == Helpdesk::TicketField::CUSTOM_FILE && v.present?
                                               v.to_i.zero? ? nil : v.to_i
                                             else
                                               v
                                             end
    end
    custom_fields_hash
  end

  def requester
    private_api? ? requester_info : requester_v2
  rescue StandardError => e
    Rails.logger.error("Error while fetching requester for Ticket Id: #{record.id}: #{e.message}")
    NewRelic::Agent.notice_error(e, description: "Error while fetching requester for Ticket #{record.id} for Account #{Account.current.id}")
  end

  def requester_v2
    if @sideload_options.include?('requester')
      requester = record.requester
      {
        id: requester.id,
        name: requester.name,
        email: requester.email,
        mobile: requester.mobile,
        phone: requester.phone
      }
    end
  end

  def requester_info
    return unless @sideload_options.include?('requester')
    options = { name_mapping: @contact_name_mapping, sideload_options: ['company'] }
    requester_hash = ContactDecorator.new(record.requester, options).requester_hash
    requester_hash[:language] = record.requester.language
    requester_hash[:address] = record.requester.address
    requester_hash
  end

  def description_hash
    return false unless description_allowed?

    description_info
  end

  def description_info
    return default_description_info unless restrict_twitter_ticket_content?

    {
      description: restricted_twitter_ticket_content,
      description_text: restricted_twitter_ticket_content
    }
  end

  def default_description_info
    ticket_body = record.archive? ? record : record.ticket_body
    {
      description: ticket_body.description_html,
      description_text: ticket_body.description
    }
  end

  def subject_info
    restrict_twitter_ticket_content? ? restricted_twitter_ticket_content : record.subject
  end

  def twitter_ticket?
    (Account.current.has_feature?(:advanced_twitter) || Account.current.basic_twitter_enabled?) && record.source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:twitter] && record.tweet
  end

  def restrict_twitter_ticket_content?
    Account.current.twitter_api_compliance_enabled? && twitter_ticket? && !private_api? && !channel_v2_api?
  end

  def restricted_twitter_ticket_content
    if record.tweet.tweet_type == Social::Twitter::Constants::TWITTER_NOTE_TYPE[:mention]
      "View the tweet at https://twitter.com/#{record.tweet.twitter_handle_id}/status/#{record.tweet.tweet_id}"
    else
      'View the message at https://twitter.com/messages'
    end
  end

  def description_allowed?
    @sideload_options.include?('description')
  end

  def custom_fields_allowed?
    @sideload_options.include?('custom_fields')
  end

  def ticket_states_association
    @ticket_states_association ||= ticket_states
  end

  def stats
    return unless private_api? || channel_v2_api? || @sideload_options.include?('stats')
    states = {
      agent_responded_at: ticket_states_association.agent_responded_at.try(:utc),
      requester_responded_at: ticket_states_association.requester_responded_at.try(:utc),
      first_responded_at: ticket_states_association.first_response_time.try(:utc),
      status_updated_at: ticket_states_association.status_updated_at.try(:utc),
      reopened_at: ticket_states_association.opened_at.try(:utc)
    }.merge(dirty_fixed_stats)
    return states unless channel_v2_api?
    states.merge({
      first_assigned_at: ticket_states_association.first_assigned_at.try(:utc),
      assigned_at: ticket_states_association.assigned_at.try(:utc),
      sla_timer_stopped_at: ticket_states_association.sla_timer_stopped_at.try(:utc),
      avg_response_time_by_bhrs: ticket_states_association.avg_response_time_by_bhrs,
      resolution_time_by_bhrs: ticket_states_association.resolution_time_by_bhrs,
      on_state_time: ticket_states_association.on_state_time,
      inbound_count: ticket_states_association.inbound_count,
      outbound_count: ticket_states_association.outbound_count,
      group_escalated: ticket_states_association.group_escalated,
      first_resp_time_by_bhrs: ticket_states_association.first_resp_time_by_bhrs,
      avg_response_time: ticket_states_association.avg_response_time,
      resolution_time_updated_at: ticket_states_association.resolution_time_updated_at.try(:utc)
    })
  end

  def channel_v2_attributes
    {
      import_id: import_id,
      ticket_id: id,
      deleted: deleted
    } if channel_v2_api?
  end

  def fb_post
    return unless (Account.current.has_feature?(:advanced_facebook) || Account.current.basic_facebook_enabled?) && record.facebook?
    FacebookPostDecorator.new(record.fb_post).to_hash
  end

  def tweet
    return unless (Account.current.has_feature?(:advanced_twitter) || Account.current.basic_twitter_enabled?) && record.twitter?
    tweet = record.tweet
    {
      tweet_id: tweet.tweet_id.to_s,
      tweet_type: tweet.tweet_type,
      twitter_handle_id: tweet.twitter_handle_id
    }
  end

  def social_additional_info_hash
    tweet_hash = { tweet_type: record.tweet_type } if record.tweet_type.present?
    fb_hash = { fb_msg_type: record.fb_msg_type } if record.fb_msg_type.present?
    social_additional_info_hash = tweet_hash || fb_hash
    social_additional_info_hash
  end

  def ebay
    return unless Account.current.has_feature?(:ecommerce) && record.ecommerce? && record.ebay_account.present?

    {
      name: record.ebay_account.name
    }
  end

  def facebook_public_hash
    return unless (Account.current.has_feature?(:advanced_facebook) || Account.current.basic_facebook_enabled?) && record.facebook?
    FacebookPostDecorator.new(record.fb_post).public_hash
  end

  def tweet_public_hash
    return unless (Account.current.has_feature?(:advanced_twitter) || Account.current.basic_twitter_enabled?) && record.twitter? && record.tweet.twitter_handle
    tweet = record.tweet
    handle = record.tweet.twitter_handle
    tweet_hash = {
      id: tweet.tweet_id.to_s,
      type: tweet.tweet_type,
      support_handle_id: handle.twitter_user_id.to_s,
      support_screen_name: handle.screen_name,
      requester_screen_name: Account.current.twitter_api_compliance_enabled? && !channel_v2_api? ? nil : record.requester.twitter_id
    }
    tweet_hash[:stream_id] = tweet.stream_id if channel_v2_api?
    tweet_hash
  end

  def conversations
    if @sideload_options.include?('conversations')
      preload_options = [:schema_less_note, :note_body, :attachments]
      preload_options = public_preload_options(preload_options) unless private_api?

      ticket_conversations = record.notes.
                             conversations(preload_options, :created_at, ConversationConstants::MAX_INCLUDE)
      decorator_method = private_api? ? 'construct_json' : 'public_json'
      ticket_conversations.map { |conversation| ConversationDecorator.new(conversation, ticket: record).safe_send(decorator_method) }
    end
  end

  def public_preload_options(preload_options)
    if record.facebook?
      preload_options << :fb_post
    elsif record.twitter?
      preload_options << :tweet
    end
    preload_options
  end

  def company_hash
    private_api? ? private_company_hash : company_hash_v2
  end

  def private_company_hash
    if @sideload_options.include?('company')
      company = record.company
      return unless company
      CompanyDecorator.new(company, name_mapping: @company_name_mapping).company_hash
    end
  end

  def sla_policy_hash
    if @sideload_options.include?('sla_policy')
      sla_policy = record.sla_policy
      return unless sla_policy
      SlaPolicyDecorator.new(sla_policy).to_hash
    end
  end

  def company_hash_v2
    if @sideload_options.include?('company')
      company = record.company
      return {} unless company
      { id: company.id, name: company.name }
    end
  end

  def attachments_hash
    @cdn_url = Account.current.cdn_attachments_enabled? unless defined? @cdn_url
    (attachments | attachments_sharable).map { |a| AttachmentDecorator.new(a).to_hash(@cdn_url) }
  end

  def cloud_files_hash
    cloud_files.map { |cf| CloudFileDecorator.new(cf).to_hash }
  end

  def archive_ticket_hash
    return nil unless private_api? && Account.current.features_included?(:archive_tickets) && record.archive_child
    archive_ticket = record.archive_ticket
    {
      id: archive_ticket.display_id,
      subject: archive_ticket.subject
    }
  end

  def meta
    meta_info = record.notes.find_by_source(Account.current.helpdesk_sources.note_source_keys_by_token['meta'])
    return {} unless meta_info
    meta_info = YAML.load(meta_info.body)
    handle_timestamps(meta_info)
  rescue
    # Errors suppressed
    {}
  end

  def feedback_hash
    return {} unless @sideload_options.include?('survey') && record.custom_survey_results.present?
    survey_result = record.custom_survey_results.last
    {
      survey_result: {
        survey_id: survey_result.survey_id,
        agent_id: survey_result.agent_id,
        group_id: survey_result.group_id,
        rating: survey_result.custom_ratings
      }
    }
  end

  def shared_ownership_hash
    return {} unless Account.current.shared_ownership_enabled?
    {
      internal_agent_id: internal_agent_id,
      internal_group_id: internal_group_id
    }
  end

  def skill_hash
    return {} unless Account.current.skill_based_round_robin_enabled?
    { skill_id: skill_id }
  end

  def ticket_topic
    return unless forums_enabled? && record.ticket_topic.present?
    topic = record.topic
    topic_hash(topic)
  end

  def schema_less_ticket_association
    @schema_less_ticket_association ||= schema_less_ticket
  end

  def simple_hash
    {
      id: display_id,
      group_id: group_id,
      priority: priority,
      requester_id: requester_id,
      responder_id: responder_id,
      source: source,
      company_id: company_id,
      status: status,
      subject: subject,
      product_id: schema_less_ticket_association.try(:product_id),
      type: ticket_type,
      due_by: due_by.try(:utc),
      fr_due_by: frDueBy.try(:utc),
      is_escalated: isescalated,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      email_failure_count: schema_less_ticket_association.failure_count
    }
  end

  def to_hash
    hash = {
      cc_emails: cc_email.try(:[], :cc_emails),
      fwd_emails: cc_email.try(:[], :fwd_emails),
      reply_cc_emails: cc_email.try(:[], :reply_cc),
      ticket_cc_emails: cc_email.try(:[], :tkt_cc),
      fr_escalated: fr_escalated,
      spam: spam,
      email_config_id: email_config_id,
      company_id: company_id,
      status: status,
      to_emails: schema_less_ticket_association.try(:to_emails),
      association_type: association_type,
      associated_tickets_count: subsidiary_tkts_count,
      can_be_associated: can_be_associated?,
      tags: tag_names,
      write_access: write_access?
    }
    hash[:custom_fields] = custom_fields unless @discard_options.include?('custom_fields')
    result = [hash, simple_hash, feedback_hash, shared_ownership_hash, skill_hash].inject(&:merge!)
    result.merge!(predict_ticket_fields_hash) if ticket_properties_suggester_enabled?
    result.merge!(next_response_hash) if Account.current.next_response_sla_enabled?
    result
  end

  def write_access?
    advanced_scope_enabled? ? agent_has_write_access?(record, agent_group_ids) : true
  end

  def agent_group_ids
    User.current.associated_group_ids if User.current.present?
  end

  def to_show_hash
    response_hash = to_hash
    response_hash[:description] = ticket_body.description_html
    response_hash[:description_text] = ticket_body.description

    [:requester, :stats, :conversations, :deleted, :fb_post, :tweet, :ticket_topic, :ebay, :email_spam_data, :meta].each do |attribute|
      value = safe_send(attribute)
      response_hash[attribute] = value if value
    end

    [:attachments, :cloud_files, :company, :sla_policy, :archive_ticket].each do |attribute|
      value = safe_send("#{attribute}_hash")
      response_hash[attribute] = value if value
    end

    response_hash[:sender_email] = safe_send(:sender_email)

    # response_hash[:meta] = meta
    response_hash[:collaboration] = collaboration_hash if include_collab?
    response_hash[:meta][:secret_id] = generate_secret_id if Account.current.agent_collision_revamp_enabled?
    response_hash[:social_additional_info] = { tweet_type: record.tweet_type } if source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:twitter] && response_hash[:tweet].blank?
    response_hash[:social_additional_info] = { fb_msg_type: record.fb_msg_type } if source == Account.current.helpdesk_sources.ticket_source_keys_by_token[:facebook] && response_hash[:fb_post].blank?
    response_hash
  end

  def to_search_hash
    ret_hash = {
      id: display_id,
      tags: tag_names,
      responder_id: responder_id,
      created_at: created_at.try(:utc),
      subject: subject,
      requester_id: requester_id,
      group_id: group_id,
      status: status,
      source: source,
      priority: priority,
      archived: archived?
    }
    requester_hash = requester

    ret_hash.merge!(whitelisted_properties)

    ret_hash[:company] = company_search_hash if company_id.present?
    ret_hash[:requester] = requester_hash if requester_hash
    ret_hash[:archived] = archived? if archived?
    ret_hash[:custom_fields] = custom_fields if custom_fields_allowed?
    ret_hash
  end

  def to_activity_hash
    ret_hash = activity_hash
    ret_hash[:activity_type] = TICKET_TYPE
    ret_hash
  end

  def to_timeline_hash
    activity_hash
  end

  def whitelisted_properties_for_activities
    ret_hash = whitelisted_properties
    if archived?
      ret_hash[:archived] = true
    else
      ret_hash[:tags] = tag_names
      ret_hash[:fr_due_by] = frDueBy.try(:utc)
      ret_hash[:status] = status
      ret_hash[:priority] = priority
    end
    ret_hash
  end

  def to_prime_association_hash
    hash = {
      id: display_id,
      requester_id: requester_id,
      responder_id: responder_id,
      subject: subject,
      association_type: association_type,
      status: status,
      created_at: created_at.try(:utc),
      stats: stats,
      permission: @permission
    }
    [hash, broadcast_message_hash].inject(&:merge)
  end

  def broadcast_message_hash
    return {} unless @last_broadcast_message.present?
    {
      broadcast_message: {
        body: @last_broadcast_message.body_html,
        created_at: @last_broadcast_message.created_at.try(:utc)
      }
    }
  end

  def to_associations_hash
    ret_hash = {
      permission: permission?,
      stats: stats
    }
    ret_hash[:deleted] = deleted if deleted
    [ret_hash, simple_hash].inject(&:merge)
  end

  class << self
    def display_name(name)
      name[0..(-Account.current.id.to_s.length - 2)]
    end
  end

  def collaboration_hash
    {
      convo_token: Collaboration::Ticket.new.convo_token(display_id)
    }
  end

  def generate_secret_id
    mask_id(display_id)
  end

  def sender_email
    record.requester.reload unless record.requester.emails.present?
    if record.requester.emails.include?(schema_less_ticket_association.try(:sender_email))
      schema_less_ticket_association.try(:sender_email)
    end
  end

  def predict_ticket_fields_hash
    hash = { predict_ticket_fields: false }
    ticket_properties_suggester_hash = schema_less_ticket.try(:ticket_properties_suggester_hash)
    suggested_fields = ticket_properties_suggester_hash[:suggested_fields] if ticket_properties_suggester_hash.present?
    return hash if suggested_fields.blank?
    return hash if suggested_fields.all? { |k,v| v[:updated] }

    expiry_time = ticket_properties_suggester_hash[:expiry_time]
    current_time = Time.now.to_i
    if expiry_time.present? && current_time - expiry_time > 0
      ::Freddy::TicketPropertiesSuggesterWorker.perform_async(ticket_id: record.id, action: 'predict', dispatcher_set_priority: false)
      return hash
    end
    hash[:predict_ticket_fields] = true
    hash
  end

  def email_spam_data
    record.schema_less_ticket.additional_info[:email_spoof_data] if Account.current.email_spoof_check_feature?
  end

  def next_response_hash
    {
      nr_escalated: nr_escalated,
      nr_due_by: nr_due_by.try(:utc)
    }
  end

  private

  def activity_hash
    ret_hash = {
      id: display_id,
      responder_id: responder_id,
      source: source,
      created_at: created_at.try(:utc),
      subject: subject,
      requester_id: requester_id,
      group_id: group_id
    }
    ret_hash.merge!(whitelisted_properties_for_activities)
    ret_hash
  end

  def handle_timestamps(meta_info)
    if meta_info.is_a?(Hash) && meta_info.keys.include?('time')
      meta_info['time'] = Time.parse(meta_info['time']).utc.iso8601
    end
    meta_info
  end

  def include_collab?
    Account.current.collaboration_enabled? || (Account.current.freshconnect_enabled? && Account.current.freshid_integration_enabled? && (app_current? || User.current.freshid_authorization))
  end

  def forums_enabled?
    Account.current.features?(:forums)
  end

  def topic_hash(topic)
    {
      id: topic.id,
      title: topic.title
    }
  end

  def company_search_hash
    { id: company_id, name: record.company.try(:name) }
  end

  def permission?
    @permissibles.find { |perm| perm[:display_id] == display_id }.present?
  end

  def parse_time(attribute)
    attribute ? Time.parse(attribute).utc : nil
  end

  def archived?
    @is_archived ||= record.is_a?(Helpdesk::ArchiveTicket)
  end

  def whitelisted_properties
    # For an archive ticket, these are properties which are fetched from s3 object
    # For regular Helpdesk::Ticket they are in the DB.
    # To avoid S3 fetches in search, we are doing this.
    return {} if archived?
    {
      description_text: description,
      due_by: due_by.try(:utc),
      stats: stats
    }
  end

  def dirty_fixed_stats
    DIRTY_FIX_MAPPING.each_with_object({}) do |(key, value), res|
      res[key] = ticket_states_association.safe_send(key).try(:utc) || (value.include?(status) ? ticket_states_association.updated_at.try(:utc) : nil)
      res
    end
  end

  def display_secure_text_data(field_name, value)
    return false unless private_api? && User.current.privilege?(:view_secure_field)

    ticket_field_created_at = Account.current.ticket_fields_from_cache.find { |tf| tf.name == field_name }.try(:created_at).to_i
    # Current Timestamp is stored in DB for secure_text. Valid only if ticket field was created before that and value is within ttl
    ticket_field_created_at < value && Time.now.to_i < value + TicketFieldsConstants::SECURE_TEXT_DATA_TTL
  end
end
