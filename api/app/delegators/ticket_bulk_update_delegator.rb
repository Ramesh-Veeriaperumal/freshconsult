class TicketBulkUpdateDelegator < BaseDelegator
  attr_accessor :ticket_fields

  validates :custom_field_via_mapping,  custom_field: { custom_field_via_mapping:
                              {
                                validatable_custom_fields: proc { |x| TicketsValidationHelper.custom_dropdown_fields(x) },
                                drop_down_choices: proc { TicketsValidationHelper.custom_dropdown_field_choices },
                                nested_field_choices: proc { TicketsValidationHelper.custom_nested_field_choices },
                                required_based_on_status: proc { |x| x.closure_status? },
                                required_attribute: :required,
                                section_field_mapping: proc { |x| TicketsValidationHelper.section_field_parent_field_mapping }
                              }
                            }
  validate :validate_closure, if: -> { status && attr_changed?('status') }

  def initialize(record, options = {})
    @ticket_fields = options[:ticket_fields]
    check_params_set(options[:custom_fields]) if options[:custom_fields].is_a?(Hash)
    super(record, options)
  end

  def closure_status?
    [ApiTicketConstants::CLOSED, ApiTicketConstants::RESOLVED].include?(status.to_i)
  end

  def validate_closure
    return unless closure_status?
    errors[:status] << :unresolved_child if self.assoc_parent_ticket? && self.validate_assoc_parent_tkt_status
  end
end
