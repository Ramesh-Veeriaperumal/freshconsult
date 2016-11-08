module Search
	class CompanyValidation < ApiValidation

		CHECK_PARAMS_SET_FIELDS = (%w( custom_fields )).freeze

		attr_accessor :domain, :custom_fields

		validates :domain, data_type: { rules: Array }, array: { data_type: { rules: String } }, string_rejection: { excluded_chars: [','], allow_nil: true }

	  validates :custom_fields, custom_field: { custom_fields:
	                          {
	                            validatable_custom_fields: proc { Account.current.contact_form.custom_non_dropdown_fields },
    													required_attribute: :required_for_agent,
	                            ignore_string: :allow_string_param,
	                            search_validation: :true
	                          }
	                       }

	  def initialize(request_params)
	  	super(request_params, nil, true)
	  end
	end
end
