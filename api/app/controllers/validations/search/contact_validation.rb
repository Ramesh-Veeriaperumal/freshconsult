module Search
  class ContactValidation < ApiValidation
    CHECK_PARAMS_SET_FIELDS = %w(custom_fields).freeze

    attr_accessor :company_id, :twitter_id, :active, :email, :tag, :language, :time_zone, :created_at, :updated_at, :custom_fields, :contact_custom_fields

    validates :company_id, array: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param, allow_nil: true } }
    validates :twitter_id, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: true } }
    validates :active, data_type: { rules: Array }, array: { data_type: { rules: 'Boolean',  ignore_string: :allow_string_param } }
    validates :email, data_type: { rules: Array }, array: { custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address', allow_nil: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } }
    validates :tag, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING } }
    validates :language, data_type: { rules: Array }, array: { custom_inclusion: { in: ContactConstants::LANGUAGES, detect_type: true } }
    validates :time_zone, data_type: { rules: Array }, array: { custom_inclusion: { in: ContactConstants::TIMEZONES, detect_type: true } }
    validates :created_at, :updated_at, data_type: { rules: Array }, array: { date_time: { only_date: true, allow_nil: true } }

    validates :custom_fields, custom_field: { custom_fields:
                             {
                               validatable_custom_fields: proc { |x| x.contact_custom_fields },
                               required_attribute: :required_for_agent,
                               search_validation: :true,
                               drop_down_choices: proc { |x| x.custom_dropdown_field_choices }
                             } }

    def initialize(request_params, contact_custom_fields)
      super(request_params, nil, true)
      @contact_custom_fields = contact_custom_fields
     end

    def custom_dropdown_field_choices
      Account.current.contact_form.custom_dropdown_field_choices
    end
  end
end
