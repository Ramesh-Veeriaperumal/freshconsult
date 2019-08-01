class FsmTicketValidation < TicketValidation
  attr_accessor :ticket_fields
  include Admin::AdvancedTicketing::FieldServiceManagement::Util

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
