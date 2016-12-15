module Search
	class TicketValidation < ApiValidation

		CHECK_PARAMS_SET_FIELDS = (%w( custom_fields )).freeze

		attr_accessor :group_id, :priority, :email, :requester_id, :status, :custom_fields, :ticket_fields, :status_ids, :ticket_custom_fields

		alias_attribute :requester, :requester_id
		alias_attribute :group, :group_id

	  validates :status, data_type: { rules: Array }, array: { custom_inclusion: { in: proc { |x| x.status_ids }, detect_type: true } }
    validates :priority, data_type: { rules: Array }, array: { custom_inclusion: { in: ApiTicketConstants::PRIORITIES, detect_type: true } }
    validates :requester_id, :group_id, array: { custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param } }
    validates :email, data_type: { rules: Array }, array: { data_type: { rules: String }, custom_format: { with: AccountConstants::EMAIL_VALIDATOR, accepted: :'valid email address' }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING } }

	  validates :custom_fields, custom_field: { custom_fields:
	                          {
	                            validatable_custom_fields: proc { |x| x.ticket_custom_fields },
	                            required_attribute: :required,
	                            ignore_string: :allow_string_param,
	                            search_validation: :true
	                          }
	                       }

	  def initialize(request_params, ticket_custom_fields)
	  	super(request_params, nil, true)
	  	@status_ids = request_params[:statuses].map(&:status_id)
	  	@ticket_custom_fields = ticket_custom_fields
	  end
	end
end
