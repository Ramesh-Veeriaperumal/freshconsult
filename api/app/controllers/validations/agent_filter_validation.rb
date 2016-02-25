class AgentFilterValidation < FilterValidation
  attr_accessor :state, :phone, :mobile, :email, :conditions

  validates :state, custom_inclusion: { in: AgentConstants::STATES, allow_unset: true }
  validates :email, data_type: { rules: String, allow_unset: true  }
  validates :email, format: { with: ApiConstants::EMAIL_VALIDATOR, message: 'not_a_valid_email' }, if: -> { email && errors[:email].blank? }
  validates :phone, :mobile, data_type: { rules: String, allow_unset: true }
  
  def initialize(request_params)
    # Remove unwanted keys from request_params; Also remove the state filter and add the value passed as a filter
    # Refer api_filter from user.rb
    @conditions = (request_params.keys & AgentConstants::INDEX_FIELDS) - ['state'] + [request_params['state']].compact
    super(request_params, nil, true)
    check_params_set(request_params)
  end
end
