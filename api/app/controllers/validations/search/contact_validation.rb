module Search
	class ContactValidation < ApiValidation

		CHECK_PARAMS_SET_FIELDS = (%w( custom_fields )).freeze

		attr_accessor :company_id, :twitter_id, :active, :custom_fields

		validates :company_id, array: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param } }
		validates :twitter_id, data_type: { rules: Array }, array: { data_type: { rules: String } }
		validates :active, data_type: { rules: Array }, array: { data_type: { rules: 'Boolean',  ignore_string: :allow_string_param } }

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
