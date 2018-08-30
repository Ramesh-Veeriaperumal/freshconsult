class CompanyDelegator < BaseDelegator
  validates :custom_field, custom_field: { custom_field: {
    validatable_custom_fields: proc { Account.current.company_form.custom_drop_down_fields },
    drop_down_choices: proc { Account.current.company_form.custom_dropdown_field_choices },
    required_attribute: :required_for_agent
  }
  }, unless: -> { validation_context == :channel_company_create }
  validates :custom_field, custom_field: { custom_field: {
    validatable_custom_fields: proc { Account.current.company_form.custom_drop_down_fields },
    drop_down_choices: proc { Account.current.company_form.custom_dropdown_field_choices },
  }
  }, if: -> { validation_context == :channel_company_create }

  validates :health_score, :account_tier, :industry,
            default_field: {
              required_fields: proc { |x| x.required_default_fields },
              field_validations: proc { |x| x.default_field_validations } },
              if: :tam_default_fields_enabled?

  def initialize(record, options)
    check_params_set(options[:custom_fields]) if options[:custom_fields].is_a?(Hash)
    super record
    options[:default_fields].each do |field, value|
      if CompanyConstants::DEFAULT_DROPDOWN_FIELDS.include?(field.to_sym)
        instance_variable_set("@#{field}", value)
      end
    end
  end

  def default_field_validations
    {
      health_score: { custom_inclusion: { in: proc { |x| x.valid_health_score_choices } } },
      account_tier: { custom_inclusion: { in: proc { |x| x.valid_account_tier_choices } } },
      industry: { custom_inclusion: { in: proc { |x| x.valid_industry_choices } } }
    }
  end

  def required_default_fields
    company_form.default_company_fields.select(&:required_for_agent)
  end

  def valid_health_score_choices
    company_form.default_health_score_choices
  end

  def valid_account_tier_choices
    company_form.default_account_tier_choices
  end

  def valid_industry_choices
    company_form.default_industry_choices
  end

  private

    def company_form
      @company_form ||= Account.current.company_form
    end

    def tam_default_fields_enabled?
      Account.current.tam_default_fields_enabled?
    end
end
