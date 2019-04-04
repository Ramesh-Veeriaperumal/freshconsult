class AgentFilterValidation < FilterValidation
  attr_accessor :state, :phone, :mobile, :email, :conditions, :only, :type, :privilege

  validates :state, custom_inclusion: { in: AgentConstants::STATES }
  validates :email, data_type: { rules: String }
  validates :email, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address', allow_nil: true }

  validates :phone, :mobile, data_type: { rules: String }
  validates :only, custom_inclusion: { in: AgentConstants::ALLOWED_ONLY_PARAMS }, data_type: { rules: String }

  validates :type, allow_nil: false, custom_inclusion: { in: proc { |x| x.account_agent_types }, data_type: { rules: String } }

  validate :validate_privilege

  def initialize(request_params)
    # Remove unwanted keys from request_params; Also remove the state filter and add the value passed as a filter
    # Refer api_filter from user.rb
    @conditions = (request_params.keys & AgentConstants::INDEX_FIELDS) - ['state', 'only'] + [request_params['state']].compact
    super(request_params, nil, true)
  end

  def account_agent_types
    @agent_types = Account.current.agent_types_from_cache.map(&:name)
  end

  def validate_privilege
    if @only == 'with_privilege'
      errors[:privilege] << :invalid_privilege && (return false) if @privilege.blank?
      errors[:privilege] << :invalid_privilege && (return false) unless Helpdesk::Roles::ACCOUNT_ADMINISTRATOR.include?(@privilege.to_sym)
    elsif @privilege.present?
      errors[:privilege] << :privilege_not_allowed && (return false)
    end
  end
end
