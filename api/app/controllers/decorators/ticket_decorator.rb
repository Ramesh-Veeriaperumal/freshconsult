class TicketDecorator < ApiDecorator
  delegate :ticket_body, :custom_field, :cc_email, :email_config_id, :fr_escalated, :group_id, :priority,
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
    # @name_mapping will be nil for READ requests
    @name_mapping ||= custom_field.each_with_object({}) { |cf, hash| hash[cf.name] = self.class.display_name(cf.name) }
    custom_fields_hash = {}
    custom_field.each { |k, v| custom_fields_hash[@name_mapping[k]] = utc_format(v) }
    custom_fields_hash
  end

  def requester
    if record.association(:requester).loaded?
      {
        id: record.requester.id,
        name: record.requester.name,
        email: record.requester.email,
        mobile: record.requester.mobile,
        phone: record.requester.phone
      }
    end
  end
  
  class << self
    def display_name(name)
      name[0..(-Account.current.id.to_s.length - 2)]
    end
  end
end
