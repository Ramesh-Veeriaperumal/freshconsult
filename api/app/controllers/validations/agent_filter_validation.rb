class AgentFilterValidation < ApiValidation
  attr_accessor :state, :phone, :mobile, :email, :conditions

  validates :state, custom_inclusion: { in: AgentConstants::STATES }, allow_nil: true
  validates :email, format: { with: ApiConstants::EMAIL_VALIDATOR, message: 'not_a_valid_email' }, allow_nil: true

  def initialize(request_params)
    @conditions = (request_params.keys & AgentConstants::INDEX_FIELDS) - ['state'] + [request_params['state']].compact
    super(request_params)
  end
end
