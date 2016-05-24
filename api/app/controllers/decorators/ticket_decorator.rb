class TicketDecorator < ApiDecorator
  delegate :ticket_body, :custom_field_via_mapping, :cc_email, :email_config_id, :fr_escalated, :group_id, :priority,
           :requester_id,  :responder_id, :source, :spam, :status, :subject, :display_id, :ticket_type,
           :schema_less_ticket, :deleted, :due_by, :frDueBy, :isescalated, :description,
           :description_html, :tag_names, :attachments, :company_id, to: :record

  def initialize(record, options)
    super(record)
    @name_mapping = options[:name_mapping]
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
    if record.association(:requester).loaded?
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

  def stats
    if record.association(:ticket_states).loaded?
      ticket_states = record.ticket_states
      {
        resolved_at: ticket_states.resolved_at.try(:utc),
        first_responded_at: ticket_states.first_response_time.try(:utc),
        closed_at: ticket_states.closed_at.try(:utc)
      }
    end
  end

  class << self
    def display_name(name)
      name[0..(-Account.current.id.to_s.length - 2)]
    end
  end
end
