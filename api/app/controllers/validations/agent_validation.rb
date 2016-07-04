class AgentValidation < ApiValidation
  attr_accessor :name, :phone, :mobile, :email, :time_zone, :language, :occasional, :signature, :ticket_scope,
                :role_ids, :group_ids, :job_title, :id

  CHECK_PARAMS_SET_FIELDS = %w(time_zone language occasional role_ids ticket_scope).freeze

  validates :name, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :job_title, :phone, :mobile, data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :email, data_type: { rules: String, required: true }, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :language, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field,  message_options: { attribute: 'language', feature: :multi_language } }, unless: :multi_language_enabled?
  validates :time_zone, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field, message_options: { attribute: 'time_zone', feature: :multi_timezone } }, unless: :multi_timezone_enabled?
  validates :role_ids, :ticket_scope, custom_absence: { message: :agent_roles_and_scope_error, code: :inaccessible_field  }, if: -> { id && User.current.id == id }
  validates :language, custom_inclusion: { in: ContactConstants::LANGUAGES }
  validates :time_zone, custom_inclusion: { in: ContactConstants::TIMEZONES }
  validates :occasional, data_type: { rules: 'Boolean' }
  validates :signature, data_type: { rules: String, allow_nil: true }
  validates :ticket_scope, custom_inclusion: { in: AgentConstants::TICKET_SCOPES, detect_type: true  }
  validates :group_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0 } }
  validates :role_ids, required: true, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0 } }
  validate :check_agent_limit, if: -> { @occasional_set && @previous_occasional && @occasional == false }

  def initialize(request_params, item, allow_string_param = false)
    user = item.user
    @previous_occasional = item.occasional
    @role_ids = user.roles.map(&:id) if user
    super(request_params, user, allow_string_param)
  end

  def check_agent_limit
    agent_limit_reached, agent_limit = ApiUserHelper.agent_limit_reached?
    if agent_limit_reached
      errors[:occasional] = :max_agents_reached
      (error_options[:occasional] ||= {}).merge!(max_count: agent_limit, code: :incompatible_value)
    end
  end

  def multi_language_enabled?
    Account.current.features?(:multi_language)
  end

  def multi_timezone_enabled?
    Account.current.features?(:multi_timezone)
  end
end
