class FsmTicketValidation < TicketValidation

	def custom_fields_to_validate
		account_id = Account.current.id
		required_fields_fsm_with_id = Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_MANDATORY_FIELDS.map {|field| "cf_#{field}_#{account_id}"}
		tkt_fields = []
		TicketsValidationHelper.custom_non_dropdown_fields(self).each do |field|
			if required_fields_fsm_with_id.include?(field.name)
				tkt_fields << field
			end
		end
		create_or_update? ? tkt_fields : tkt_fields.select { |x| validate_field?(x) }
	end
end
