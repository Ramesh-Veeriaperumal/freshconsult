class Admin::TicketFieldDecorator < ApiDecorator
  include Admin::TicketFieldConstants
  delegate :field_type, :field_options, :parent_id, to: :record

  def initialize(record, options)
    super(record, options)
  end

  def to_hash(list = false)
    return if((record.product_field? && current_account.products_from_cache.length == 0) || (record.nested_field? && parent_id.present?))
    return form_item_hash
  end

  def form_item_hash
    response = {}
    TICKET_FIELDS_RESPONSE_HASH.each_pair do |key, value|
      response[key] = record.safe_send(value) unless record.safe_send(value).nil?
      response[key] = record.display_ticket_field_name if key == :name && record.name.starts_with?("cf_")
    end
    response.merge!(HAS_SECTION => field_options[SECTION_PRESENT]) if record.has_sections?
    if record.requester_field?
      response.merge!(PORTAL_CC => field_options[PORTALCC])
      response.merge!(PORTAL_CC_TO => field_options[PORTALCC_TO])
    end
    response
  end
end