class TicketDecorator < ApiDecorator
  delegate :ticket_body, :custom_field_via_mapping, :cc_email, :email_config_id, :fr_escalated, :group_id, :priority,
           :requester_id,  :responder_id, :source, :spam, :status, :subject, :display_id, :ticket_type,
           :schema_less_ticket, :deleted, :due_by, :frDueBy, :isescalated, :description,
           :description_html, :tag_names, :attachments, :company_id, to: :record

  def initialize(record, options)
    super(record)
    @name_mapping = options[:name_mapping]
    @sideload_options = options[:sideload_options]
    
  end

  def utc_format(value)
    value.respond_to?(:utc) ? value.utc : value
  end

  def custom_fields
    custom_fields_hash = {}
    custom_field_via_mapping.each { |k, v| custom_fields_hash[@name_mapping[k]] = utc_format(v) }
    custom_fields_hash
  end

  def requester
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

  def freshfone_call
    call = record.freshfone_call
    return unless call.present? && call.recording_url.present? && call.recording_audio
    {
      id: call.id,
      duration: call.call_duration,
      recording: AttachmentDecorator.new(call.recording_audio).to_hash
    }
  end

  def stats
    if @sideload_options.include?('stats')
      ticket_states = record.ticket_states
      {
        agent_responded_at: ticket_states.agent_responded_at.try(:utc),
        requester_responded_at: ticket_states.requester_responded_at.try(:utc),
        resolved_at: ticket_states.resolved_at.try(:utc),
        first_responded_at: ticket_states.first_response_time.try(:utc),
        closed_at: ticket_states.closed_at.try(:utc)
      }
    end
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
    attachments.map { |a| AttachmentDecorator.new(a).to_hash }
  end

  def meta
    meta_info = record.notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["meta"]).body
    meta_info = YAML::load(meta_info)
    handle_timestamps(meta_info)
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
end
