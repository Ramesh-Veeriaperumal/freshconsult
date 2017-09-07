module Search
	class TicketValidation < ApiValidation

		CHECK_PARAMS_SET_FIELDS = (%w( custom_fields )).freeze

		attr_accessor :group_id, :priority, :status, :custom_fields, :ticket_fields, :status_ids, :ticket_custom_fields,
									:created_at, :updated_at, :due_by, :fr_due_by, :type, :tag, :agent_id

	  validates :status, data_type: { rules: Array }, array: { custom_inclusion: { in: proc { |x| x.status_ids }, detect_type: true } }
    validates :priority, data_type: { rules: Array }, array: { custom_inclusion: { in: ApiTicketConstants::PRIORITIES, detect_type: true } }
    validates :group_id, :agent_id, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true } }
    validates :created_at, :updated_at, :fr_due_by, :due_by, data_type: { rules: Array }, array: { date_time: { only_date: true, allow_nil: true } }
    validates :type, data_type: { rules: Array }, array: { custom_inclusion: { in: proc { TicketsValidationHelper.ticket_type_values }, allow_nil: true } }
    validates :tag, data_type: { rules: Array }, array: { data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING } }

	  validates :custom_fields, custom_field: { custom_fields:
	                          {
	                            validatable_custom_fields: proc { |x| x.ticket_custom_fields },
	                            required_attribute: :required,
	                            search_validation: :true,
	                            drop_down_choices: proc { TicketsValidationHelper.custom_dropdown_field_choices }
	                          }
	                       }

	  def initialize(request_params, ticket_custom_fields)
	  	super(request_params, nil, true)
	  	@status_ids = request_params[:statuses].map(&:status_id)
	  	@ticket_custom_fields = ticket_custom_fields
	  end
	end
end