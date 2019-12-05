class Admin::TicketFieldDecorator < ApiDecorator
  include Admin::TicketFieldConstants
  include Admin::TicketFieldHelper
  delegate :id, :field_type, :field_options, :parent_id, to: :record

  def initialize(record, options)
    @include_rel = options[:include] && options[:include].to_s.split(',')
    super(record, options)
  end

  def to_hash(list = false)
    response = {}
    return response if ignored_fields? && list
    TICKET_FIELDS_RESPONSE_HASH.each_pair do |key, value|
      response[key] = record.safe_send(value) unless record.safe_send(value).nil?
      if NOT_ALLOWED_PORTAL_PARAMS.include?(key)
        response[key] ||= false
      end
      response[key] = TicketDecorator.display_name(record.name) if key == :name && !record.default?
    end
    add_requester_field(response)
    if record.has_sections?
      response[HAS_SECTION] = field_options[SECTION_PRESENT]
      response[:sections] = construct_sections(record) if @include_rel.respond_to?(:include?) && @include_rel.include?('section')
    end
    response[:choices] = record.new_formatted_choices if record.choices? && !list
    section_mapping_response(record, response)
    dependent_fields_response(record, response)
    response
  end

  def add_requester_field(response)
    if record.requester_field?
      response[PORTAL_CC] = field_options[PORTALCC]
      response[PORTAL_CC_TO] = field_options[PORTALCC_TO]
    end
  end

  def ignored_fields?
    (record.nested_field? && parent_id.present?)
  end

  def current_account
    @current_account ||= Account.current
  end
end
