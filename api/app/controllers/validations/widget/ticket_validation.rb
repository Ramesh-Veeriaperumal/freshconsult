module Widget
  class TicketValidation < ::TicketValidation
    attr_accessor :email, :description, :subject, :ticket_fields, :additional_params
    # required for simple form / field form
    validates :email, :description, required: { message: :field_validation_for_widget }, if: -> { !is_ticket_field_form? }
    # ticket fields validations will be taken care by parent validation class
    # overridden to skip ticket field required validation
    validates :description, :subject, :ticket_type, :status, :priority, :product, :agent, :group, :internal_group_id, :internal_agent_id, default_field:
                              {
                                required_fields: proc { |x| x.required_default_customer_fields },
                                field_validations: proc { |x| x.default_field_validations }
                              }, if: :is_ticket_field_form?

    validates :custom_fields, custom_field: { custom_fields:
                              {
                                validatable_custom_fields: proc { |x| x.required_custom_fields_to_validate },
                                required_attribute: :required_in_portal,
                                ignore_string: :allow_string_param,
                                section_field_mapping: proc { |x| TicketsValidationHelper.section_field_parent_field_mapping }
                              } }, if: :is_ticket_field_form?
    validates :custom_fields, custom_field: { custom_fields:
                              {
                                validatable_custom_fields: proc { |x| TicketsValidationHelper.custom_dropdown_fields(x) },
                                drop_down_choices: proc { TicketsValidationHelper.custom_dropdown_field_choices },
                                nested_field_choices: proc { TicketsValidationHelper.custom_nested_field_choices },
                                required_based_on_status: proc { |x| x.closure_status? },
                                required_attribute: :required_in_portal,
                                section_field_mapping: proc { |x| TicketsValidationHelper.section_field_parent_field_mapping }
                              } }, if: :is_ticket_field_form?

    def required_default_fields
      []
    end

    def custom_fields_to_validate
      []
    end

    def is_ticket_field_form?
      additional_params[:is_ticket_fields_form]
    end

    def required_default_customer_fields
      ticket_fields.select { |x| x.default && x.required_in_portal }
    end

    def required_custom_fields_to_validate
      tkt_fields = TicketsValidationHelper.custom_non_dropdown_fields(self)
    end
  end
end
