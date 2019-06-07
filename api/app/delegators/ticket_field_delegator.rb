# Validates when there sql queries dependent on other fields.

class TicketFieldDelegator < BaseDelegator
  validates :column_name, exceeded_limit: { error_label: :type }
  validate :validate_name_uniqueness_per_account
  validate :validate_nested_field_labels, if: :nested_field?

  def validate_name_uniqueness_per_account
    result = Account.current.ticket_fields.select(1).where(name: name)
    errors[:label] << :"has already been taken" if result.present?
  end

  def validate_nested_field_labels
    return if errors[:label].present?

    all_field_names = nested_ticket_fields.map(&:name) << name
    result = Account.current.ticket_fields_with_nested_fields.select(1).where(name: all_field_names)
    errors[:label] << :duplicate_labels_ticket_field if result.present?
  end
end
