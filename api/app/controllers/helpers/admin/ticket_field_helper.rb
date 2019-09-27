module Admin::TicketFieldHelper
  include Admin::SectionHelper
  include Admin::TicketFields::NestedFieldHelper

  private

    def run_validation(options = {})
      validator_klass = validation_class.new(params, @item, options)
      delegator_klass = delegation_class.new(@item, params)
      errors = nil
      error_options = {}
      if validator_klass.invalid?(params[:action].to_sym)
        errors = validator_klass.errors
        error_options = validator_klass.error_options
      elsif delegator_klass.invalid?(params[:action].to_sym)
        errors = delegator_klass.errors
        error_options = delegator_klass.error_options
      end
      render_errors(errors, error_options) if errors.present?
    end

    def default_field_check
      errors[:"#{tf[:name]}"] << :delete_default_field_error
      error_options[:"#{tf[:name]}"] = { name: tf[:name] }
    end

    def custom_dropdown?
      tf.present? && tf[:field_type] == 'custom_dropdown'
    end

    def default_ticket_type?
      tf.present? && tf[:field_type] == 'default_ticket_type'
    end

    def ticket_field_has_section?
      if tf.has_sections?
        errors[:"#{tf[:name]}"] << :section_inside_ticket_field_error
        error_options[:"#{tf[:name]}"] = { name: tf[:label] || tf[:name] }
      end
    end

    def update_or_destroy?
      validation_context == :update || validation_context == :destroy
    end

    def create_or_update?
      validation_context == :create || validation_context == :update
    end

    def dynamic_section?
      unless Account.current.features?(:dynamic_sections)
        errors[:dynamic_sections] << :require_feature
        error_options.merge!(dynamic_sections: { feature: :dynamic_sections,
                                                 code: :access_denied })
      end
    end

    def multi_dynamic_section?
      unless Account.current.multi_dynamic_sections_enabled?
        errors[:multi_dynamic_sections] << :require_feature
        error_options.merge!(multi_dynamic_sections: { feature: :multi_dynamic_sections,
                                                       code: :access_denied })
      end
    end

    def custom_ticket_fields_feature?
      unless Account.current.custom_ticket_fields_enabled?
        errors[:custom_ticket_fields] << :require_feature
        error_options.merge!(custom_ticket_fields: { feature: :custom_ticket_fields,
                                                     code: :access_denied })
      end
    end

    def empty_choice_error
      errors[:invalid_request] << :clear_ticket_field_choices_error
    end
end
