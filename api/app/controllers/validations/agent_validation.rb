class AgentValidation < ApiValidation
  attr_accessor :name, :phone, :mobile, :email, :time_zone, :language, :occasional, :signature, :ticket_scope,
                :role_ids, :group_ids, :job_title, :id, :shorcuts_enabled, :avatar_id, :search_settings

  CHECK_PARAMS_SET_FIELDS = %w[time_zone language occasional role_ids ticket_scope search_settings].freeze

  validates :name, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :job_title, :phone, :mobile, data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :email, data_type: { rules: String, required: true }, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :language, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field,  message_options: { attribute: 'language', feature: :multi_language } }, unless: :multi_language_enabled?
  validates :time_zone, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field, message_options: { attribute: 'time_zone', feature: :multi_timezone } }, unless: :multi_timezone_enabled?
  validates :role_ids, :ticket_scope, custom_absence: { message: :agent_roles_and_scope_error, code: :inaccessible_field }, if: -> { id && User.current.id == id }
  validates :language, custom_inclusion: { in: ContactConstants::LANGUAGES }
  validates :time_zone, custom_inclusion: { in: ContactConstants::TIMEZONES }
  validates :occasional, data_type: { rules: 'Boolean' }
  validates :signature, data_type: { rules: String, allow_nil: true }
  validates :ticket_scope, custom_inclusion: { in: AgentConstants::TICKET_SCOPES, detect_type: true }
  validates :group_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0 } }
  validates :role_ids, required: true, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0 } }, unless: :bulk_create?
  validate :check_agent_limit, if: -> { @occasional_set && @previous_occasional && @occasional == false }
  validates :shorcuts_enabled, data_type: { rules: 'Boolean' }
  validates :search_settings, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field, message_options: { attribute: 'search_settings', feature: :search_settings } }, unless: :search_settings_update?
  validates :search_settings, data_type: { rules: Hash }, presence: true, hash: { validatable_fields_hash: proc { |x| x.search_settings_format } }, if: :search_settings_update?
  validate :check_ticket_search_settings, if: :search_settings_update?

  validates :avatar_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }, if: -> { private_api? }

  def initialize(request_params, item, allow_string_param = false)
    if item
      user = item.user
      @previous_occasional = item.occasional
      @role_ids = user.roles.map(&:id) if user
      super(request_params, user, allow_string_param)
    else
      super(request_params, nil, allow_string_param)
    end
  end

  def search_settings_format
    {
      tickets: {
        data_type: {
          rules: Hash
        },
        hash: {
          validatable_fields_hash: proc { ticket_search_settings_format }
        }
      }
    }
  end

  def ticket_search_settings_format
    ticket_search_settings_format = {}
    AgentConstants::TICKET_SEARCH_SETTINGS.each do |key|
      ticket_search_settings_format[key] = {
        data_type: {
          rules: 'Boolean'
        }
      }
    end
    ticket_search_settings_format
  end

  def check_agent_limit
    agent_limit_reached, agent_limit = ApiUserHelper.agent_limit_reached?
    if agent_limit_reached
      errors[:occasional] = :max_agents_reached
      (error_options[:occasional] ||= {}).merge!(max_count: agent_limit, code: :incompatible_value)
    end
  end

  def check_ticket_search_settings
    @search_settings.each_key do |key|
      return errors[key] = :ticket_search_settings_blank if @search_settings[key].blank?
    end
  end

  def multi_language_enabled?
    Account.current.features?(:multi_language)
  end

  def multi_timezone_enabled?
    Account.current.multi_timezone_enabled?
  end

  def bulk_create?
    [:create_multiple].include?(validation_context)
  end

  def search_settings_enabled?
    Account.current.search_settings_enabled?
  end

  def search_settings_update?
    @search_settings && search_settings_enabled?
  end
end
