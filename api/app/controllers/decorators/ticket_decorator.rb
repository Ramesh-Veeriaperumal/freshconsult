class TicketDecorator
  attr_accessor :record
  
  delegate :ticket_body, :custom_field, :cc_email, :email_config_id, :fr_escalated, :group_id, :priority,
  :requester_id,  :responder_id, :source, :spam, :status, :subject, :display_id, :ticket_type, 
  :schema_less_ticket, :deleted, :created_at, :updated_at, :due_by, :frDueBy, :isescalated, :description,
  :description_html, :tag_names, :attachments, to: :record

  def initialize(record, options)
    @record = record
    @name_mapping = options[:name_mapping]
  end

  def utc_format(value)
    value.respond_to?(:utc) ? value.utc : value
  end

  def custom_fields
    # @name_mapping will be nil for READ requests
    @name_mapping ||= custom_field.each_with_object({}) {|cf, hash| hash[cf.name] = self.class.without_account_id(cf.name)}
    custom_fields_hash = {}
    custom_field.each {|k, v| custom_fields_hash[@name_mapping[k.to_sym]] = utc_format(v)}
    custom_fields_hash
  end

  class << self
    def without_account_id(name)
      name[0..(-Account.current.id.to_s.length-2)]
    end

    def append_account_id(name)
      "#{name}_#{Account.current.id}"
    end
  end
end