module Search
  class CompanyValidation < ApiValidation
    CHECK_PARAMS_SET_FIELDS = %w(custom_fields).freeze

    attr_accessor :domain, :created_at, :updated_at, :custom_fields, :company_custom_fields

    validates :domain, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: true } }, string_rejection: { excluded_chars: [','] }
    validates :created_at, :updated_at, data_type: { rules: Array }, array: { date_time: { only_date: true, allow_nil: true } }

    validates :custom_fields, custom_field: { custom_fields:
                             {
                               validatable_custom_fields: proc { |x| x.company_custom_fields },
                               required_attribute: :required_for_agent,
                               search_validation: :true,
                               drop_down_choices: proc { |x| x.custom_dropdown_field_choices }
                             } }

    def initialize(request_params, company_custom_fields)
      super(request_params, nil, true)
      @company_custom_fields = company_custom_fields
    end

    def custom_dropdown_field_choices
      Account.current.company_form.custom_dropdown_field_choices
    end
  end
end
