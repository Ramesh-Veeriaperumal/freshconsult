module Admin::TicketFieldHelper
  include UtilityHelper
  include Admin::SectionHelper
  include Admin::PicklistValueHelper
  include Admin::TicketFieldConstants
  include Admin::TicketFieldsErrorHelper
  include Admin::TicketFields::NestedFieldHelper
  include Admin::DefaultFieldHelper

  private

    def ticket_field_position_validation
      return if errors.present?

      db_position = tf.frontend_to_db_position(position)
      max_position = tf.account_ticket_field_position_mapping_from_cache[:db_to_ui][-1]
      ticket_field_position_error(tf, max_position) if db_position.blank? && position > max_position
    end

    def move_to_background_job?
      choice_count = 0
      (cname_params[:choices] || []).each do |level1|
        next unless level1.is_a?(Hash)
        level2_choices = level1[:choices] || []
        level2_choices.each do |level2|
          next unless level2.is_a?(Hash)
          choice_count += (level2[:choices] || []).length
          choice_count += 1
        end
        choice_count += 1
      end
      choice_count > CHOICE_LIMIT_BEFORE_GOING_BACKGROUND
    end

    def section_mapping_response(ticket_field, response)
      section_mapping = ticket_field.section_mappings.map do |section_field|
        SECTION_MAPPING_RESPONSE_HASH.each_with_object({}) do |value, mapping|
          mapping[value[0]] = section_field[value[1]]
        end
      end
      response.merge!(section_mappings: section_mapping) if section_mapping.present?
    end

    def dependent_fields_response(ticket_field, response)
      dependent_field = ticket_field.dependent_fields.map do |section_field|
        DEPENDENT_FIELD_RESPONSE_HASH.each_with_object({}) do |value, mapping|
          data = section_field[value[1]]
          data = TicketDecorator.display_name(data) if value[0] == :name
          mapping[value[0]] = data
        end
      end
      response.merge!(dependent_fields: dependent_field) if dependent_field.present?
    end

    def run_validation(options = {})
      validator_klass = validation_class.new(params, @item, options)
      delegator_klass = delegation_class.new(@item, params, options)
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

    def create_action?
      validation_context == :create
    end

    def update_action?
      validation_context == :update
    end
    
    def delete_action?
      validation_context == :delete
    end

    def show_or_index?
      validation_context == :show || validation_context == :index
    end

    def not_index?
      validation_context != :index
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

    def multi_product_feature?
      unless Account.current.multi_product_enabled?
        errors[:multi_product] << :require_feature
        error_options.merge!(multi_product: { feature: :multi_product,
                                              code: :access_denied })
      end
    end

    def multi_company_feature?
      unless Account.current.multiple_user_companies_enabled?
        errors[:multiple_user_companies] << :require_feature
        error_options.merge!(multiple_user_companies: { feature: :multiple_user_companies,
                                                        code: :access_denied })
      end
    end

    def hipaa_encrypted_field?
      unless current_account.hipaa_enabled?
        errors[:hipaa] << :require_feature
        error_options[:hipaa] = { feature: :hipaa, code: :access_denied }
      end
      unless current_account.custom_encrypted_fields_enabled?
        errors[:custom_encrypted_fields] << :require_feature
        error_options.merge!(custom_encrypted_fields: { feature: :custom_encrypted_fields,
                                                        code: :access_denied })
      end
    end

    def empty_choice_error
      errors[:invalid_request] << :clear_ticket_field_choices_error
    end

    def custom_dropdown?
      (tf.present? && tf[:field_type] == 'custom_dropdown') ||
        (type.present? && type.is_a?(String) && type.to_sym == :custom_dropdown)
    end

    def default_ticket_type?
      (tf.present? && tf[:field_type] == 'default_ticket_type') ||
        (type.present? && type.is_a?(String) && (type.to_sym == :default_ticket_type))
    end

    def dropdown?
      default_ticket_type? || custom_dropdown?
    end

    def nested_field?
      (tf.present? && tf.nested_field?) ||
        type.present? && type.is_a?(String) && (type.to_sym == :nested_field)
    end

    def choices_required_for_type?
      default_ticket_type? || nested_field? || dropdown?
    end

    def status_field?
      tf.present? && tf.safe_send(:status_field?)
    end

    def encrypted_field?
      (type.present? && type.is_a?(String) && type.to_sym == :encrypted_text)
    end

    def current_account
      @account ||= Account.current
    end

    def secure_field?
      (type.present? && type.is_a?(String) && type.to_sym == :secure_text)
    end

    def pci_compliance_enabled?
      unless current_account.pci_compliance_field_enabled?
        errors[:pci_compliance_field] << :require_feature
        error_options[:pci_compliance_field] = { feature: :pci_compliance_field, code: :access_denied }
      end
    end
end
