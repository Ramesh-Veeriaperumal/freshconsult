class FsmTicketUpdatePropertyValidation < TicketUpdatePropertyValidation
  include Admin::AdvancedTicketing::FieldServiceManagement::Util

  def default_fields_to_validate
    ticket_fields.select { |x| x.default && x.name != 'product' && (validate_field?(x) || (x.required_for_closure && request_params.key?(:status) && closure_status?)) }
  end

  def custom_fields_to_validate
    fsm_custom_fields_to_validate.select { |x| x.required_for_closure && request_params.key?(:status) && closure_status? }
  end
end
