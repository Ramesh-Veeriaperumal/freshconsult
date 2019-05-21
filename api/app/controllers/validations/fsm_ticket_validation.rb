class FsmTicketValidation < TicketValidation
  def custom_fields_to_validate
    # Restricting the custom fields to validate to FSM section fields alone when the ticket type is service task
    fsm_section = Account.current.sections.preload(:section_fields).find_by_label(Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_SECTION)
    return [] if fsm_section.blank?

    fsm_field_ids = fsm_section.section_fields.map(&:ticket_field_id)
    fsm_fields_to_validate = TicketsValidationHelper.custom_non_dropdown_fields(self).select { |x| fsm_field_ids.include?(x.id)}
    create_or_update? ? fsm_fields_to_validate : fsm_fields_to_validate.select { |x| validate_field?(x) }
  end
end
