class FsmTicketValidation < TicketValidation
  include Admin::AdvancedTicketing::FieldServiceManagement::Util

  attr_accessor :ticket_fields, :cf_fsm_contact_name, :cf_fsm_phone_number, :cf_fsm_service_location

  # Custom fields validation(default fields in terms of FSM).
  # To validate FSM fields(custom fields) even though enforce_mandatory is false.
  validate :validate_fsm_default_fields, if: -> { !enforce_mandatory }

  def initialize(*args)
    super(*args)
    @custom_fields ||= {}
  end

  def validate_fsm_default_fields
    account_id = Account.current.id
    fsm_custom_field_to_reserve.select { |f| f[:required] }.map { |f| f[:name] }.each do |name|
      field_name = "#{name}_#{account_id}"
      errors.add(name, "can't be blank") if @custom_fields[field_name].blank?
    end
  end

  def custom_fields_to_validate
    fsm_fields_to_validate = fsm_custom_fields_to_validate
    create_or_update? ? fsm_fields_to_validate : fsm_fields_to_validate.select { |x| validate_field?(x) }
  end

  def required_for_closure_default_fields
    ticket_fields.select { |x| x.default && x.name != 'product' && (x.required_for_closure && closure_status?) }
  end

  def required_for_submit_or_closure_default_fields
    ticket_fields.select { |x| x.default && x.name != 'product' && (x.required || (x.required_for_closure && closure_status?)) }
  end
end
