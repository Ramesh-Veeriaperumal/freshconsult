# Used for validating field of type 'nested_field'.
class NestedTicketFieldValidation < BaseChoicesTicketFieldValidation
  attr_accessor :nested_ticket_fields

  validates :choices, nested_choices: {}

  validate :nested_ticket_fields, data_type: { required: true, rules: Array }

  validate :validate_nested_fields_count

  validate :validate_nested_field_and_label_duplicate

  def validate_nested_fields_count
    errors[:nested_ticket_fields] << :count_mismatch if nested_ticket_fields.blank? || nested_ticket_fields.size != Helpdesk::TicketField::NESTED_FIELD_LIMIT
  end

  def validate_nested_field_and_label_duplicate
    return if nested_ticket_fields.blank? || errors[:nested_ticket_fields].present?

    unique_labels = (nested_ticket_fields.map { |field| field[:label] } << label).to_set
    errors[:label] << :duplicate_label_nested_fields if unique_labels.length < 3
  end
end
