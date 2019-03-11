class FsmTicketValidation < TicketValidation
  def custom_fields_to_validate
    account_id = Account.current.id
    # Restricting the custom fields to validate to FSM fields alone when the ticket type is service task
    required_fields_fsm_with_id = Admin::AdvancedTicketing::FieldServiceManagement::Constant::CUSTOM_FIELDS_TO_RESERVE.map { |x| "#{x[:name]}_#{account_id}" }
    tkt_fields = []
    TicketsValidationHelper.custom_non_dropdown_fields(self).each do |field|
      tkt_fields << field if required_fields_fsm_with_id.include?(field.name)
    end
    create_or_update? ? tkt_fields : tkt_fields.select { |x| validate_field?(x) }
  end
end
