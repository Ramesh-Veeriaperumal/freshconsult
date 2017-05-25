class TicketDecorator < ApiDecorator
  delegate :ticket_body, :custom_field_via_mapping, :cc_email, :email_config_id, :fr_escalated, :group_id, :priority,
           :requester_id, :responder, :responder_id, :source, :spam, :status, :subject, :display_id, :ticket_type,
           :schema_less_ticket, :deleted, :due_by, :frDueBy, :isescalated, :description,
           :description_html, :tag_names, :attachments, :attachments_sharable, :company_id, :cloud_files, :ticket_states, to: :record

  def initialize(record, options)
    super(record)
    @name_mapping = options[:name_mapping]
    @contact_name_mapping = options[:contact_name_mapping]
    @company_name_mapping = options[:company_name_mapping]
    @sideload_options = options[:sideload_options] || []
  end

  def custom_fields
    custom_fields_hash = {}
    custom_field_via_mapping.each { |k, v| custom_fields_hash[@name_mapping[k]] = utc_format(v) }
    custom_fields_hash
  end

  def requester
    private_api? ? privilege_based_requester_info : requester_v2
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

  def privilege_based_requester_info
    return unless @sideload_options.include?('requester')
    contact_decorator = ContactDecorator.new(record.requester, name_mapping: @contact_name_mapping, company_name_mapping: @company_name_mapping)
    User.current.privilege?(:view_contacts) ? contact_decorator.full_requester_hash : contact_decorator.restricted_requester_hash
  end

  def freshfone_call
    if freshfone_enabled?
      call = record.freshfone_call
      return unless call.present? && call.recording_url.present? && call.recording_audio
      {
        id: call.id,
        duration: call.call_duration,
        recording: AttachmentDecorator.new(call.recording_audio).to_hash
      }
    end
  end

  def stats
    return unless private_api? || @sideload_options.include?('stats')
    {
      agent_responded_at: ticket_states.agent_responded_at.try(:utc),
      requester_responded_at: ticket_states.requester_responded_at.try(:utc),
      resolved_at: ticket_states.resolved_at.try(:utc),
      first_responded_at: ticket_states.first_response_time.try(:utc),
      closed_at: ticket_states.closed_at.try(:utc),
      status_updated_at: ticket_states.status_updated_at.try(:utc),
      pending_since: ticket_states.pending_since.try(:utc),
      reopened_at: ticket_states.opened_at.try(:utc)
    }
  end

  def fb_post
    return unless Account.current.features?(:facebook) && record.facebook?
    FacebookPostDecorator.new(record.fb_post).to_hash
  end

  def tweet
    return unless Account.current.features?(:twitter) && record.twitter?
    {
      tweet_id: "#{record.tweet.tweet_id}",
      tweet_type: record.tweet.tweet_type,
      twitter_handle_id: record.tweet.twitter_handle_id,
    }
  end

  def conversations
    if @sideload_options.include?('conversations')
      ticket_conversations = record.notes.visible.exclude_source('meta').preload(:schema_less_note, :note_old_body, :attachments).order(:created_at).limit(ConversationConstants::MAX_INCLUDE)
      ticket_conversations.map { |conversation| ConversationDecorator.new(conversation, ticket: record).construct_json }
    end
  end

  def company
    if @sideload_options.include?('company')
      company = record.company
      company ? { id: company.id, name: company.name } : {}
    end
  end

  def attachments_hash
    (attachments | attachments_sharable).map { |a| AttachmentDecorator.new(a).to_hash }
  end

  def cloud_files_hash
    cloud_files.map { |cf| CloudFileDecorator.new(cf).to_hash }
  end

  def meta
    meta_info = record.notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["meta"])
    return {} unless meta_info
    meta_info = YAML::load(meta_info.body)
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

  def ticket_topic
    return unless forums_enabled? && record.ticket_topic.present?
    topic = record.topic
    topic_hash(topic)
  end

  def to_hash
    hash = {
      cc_emails: cc_email.try(:[], :cc_emails),
      fwd_emails: cc_email.try(:[], :fwd_emails),
      reply_cc_emails: cc_email.try(:[], :reply_cc),
      fr_escalated: fr_escalated,
      spam: spam,
      email_config_id: email_config_id,
      group_id: group_id,
      priority: priority,
      requester_id: requester_id,
      responder_id: responder_id,
      source: source,
      company_id: company_id,
      status: status,
      subject: subject,
      to_emails: schema_less_ticket.try(:to_emails),
      product_id: schema_less_ticket.try(:product_id),
      id: display_id,
      type: ticket_type,
      due_by: due_by.try(:utc),
      fr_due_by: frDueBy.try(:utc),
      is_escalated: isescalated,
      description: ticket_body.description_html,
      description_text: ticket_body.description,
      custom_fields: custom_fields,
      tags: tag_names,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }
    [hash, feedback_hash].inject(&:merge)
  end

  def to_search_hash
    ret_hash = {
      id: display_id,
      description_text: description,
      tags: tag_names,
      responder_id: responder_id,
      due_by: archived? ? parse_time(due_by) : due_by.try(:utc),
      created_at: created_at.try(:utc),
      subject: subject,
      requester_id: requester_id,
      group_id: group_id,
      status: status,
      company_id: company_id,
      company_name: record.company.try(:name),
      stats: stats
    }
    requester_hash = requester
    ret_hash.merge!(requester: requester_hash) if requester_hash
    ret_hash.merge!(archived: archived?) if archived?
    ret_hash
  end

  class << self
    def display_name(name)
      name[0..(-Account.current.id.to_s.length - 2)]
    end
  end

  private
    def handle_timestamps(meta_info)
      if meta_info.is_a?(Hash) && meta_info.keys.include?('time')
        meta_info['time'] = Time.parse(meta_info['time']).utc.iso8601
      end
      meta_info
    end

    def freshfone_enabled?
      Account.current.features?(:freshfone)
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

    def parse_time(attribute)
      attribute ? Time.parse(attribute).utc : nil
    end

    def archived?
      @is_archived ||= record.is_a?(Helpdesk::ArchiveTicket)
    end

end
