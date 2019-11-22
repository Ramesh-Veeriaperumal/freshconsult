class AgentValidation < ApiValidation
  attr_accessor :name, :phone, :mobile, :email, :time_zone, :language, :occasional, :signature, :ticket_scope,
                :role_ids, :group_ids, :job_title, :id, :shortcuts_enabled, :avatar_id, :search_settings, :agent_type

  CHECK_PARAMS_SET_FIELDS = %w[time_zone language occasional role_ids ticket_scope search_settings].freeze

  validates :name, data_type: { rules: String, required: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }, on: :update
  validates :name, data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }, on: :create
  validates :name, data_type: { rules: String, required: true }, if: -> { !Account.current.freshid_integration_enabled? }, on: :create
  validates :job_title, :phone, :mobile, data_type: { rules: String, allow_nil: true }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :agent_type, custom_inclusion: { in: AgentConstants::AGENT_TYPES, detect_type: true }, on: :create
  validates :email, data_type: { rules: String, required: true }, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address' }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :language, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field,  message_options: { attribute: 'language', feature: :multi_language } }, unless: :multi_language_enabled?
  validates :time_zone, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field, message_options: { attribute: 'time_zone', feature: :multi_timezone } }, unless: :multi_timezone_enabled?
  validates :role_ids, :ticket_scope, custom_absence: { message: :agent_roles_and_scope_error, code: :inaccessible_field }, if: -> { id && User.current.id == id }
  validates :language, custom_inclusion: { in: ContactConstants::LANGUAGES }
  validates :time_zone, custom_inclusion: { in: ContactConstants::TIMEZONES }
  validates :occasional, data_type: { rules: 'Boolean' }
  validates :signature, data_type: { rules: String, allow_nil: true }
  validates :ticket_scope, custom_inclusion: { in: AgentConstants::TICKET_SCOPES, detect_type: true }
  validates :ticket_scope, custom_inclusion: { in: AgentConstants::FIELD_AGENT_SCOPES, detect_type: true }, if: :is_a_field_agent?
  validates :email, :ticket_scope, required: true, on: :create
  validates :group_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0 } }
  validates :role_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0 } }, unless: :bulk_create?
  validates :role_ids, required: true, on: :update
  validate :check_agent_limit, if: -> { (@occasional_set && @previous_occasional && @occasional == false && self.validation_context == :update) || (self.validation_context == :create) }
  validate :check_field_agent_limit, :check_agent_type_with_role_ids, if: -> { Account.current.field_service_management_enabled? }, on: :create
  validates :shortcuts_enabled, data_type: { rules: 'Boolean' }
  validates :search_settings, data_type: { rules: Hash }, presence: true, hash: { validatable_fields_hash: proc { |x| x.search_settings_format } }, if: -> { @search_settings }
  validate :check_ticket_search_settings, if: -> { @search_settings.present? }

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
    return if is_a_field_agent?
    agent_limit_reached, agent_limit = ApiUserHelper.agent_limit_reached?
    if agent_limit_reached
      return if validation_context == :create && (occasional == true || occasional.nil?)
      errors[:occasional] = :max_agents_reached
      (error_options[:occasional] ||= {}).merge!(max_count: agent_limit, code: :incompatible_value)
    end
  end

  def check_agent_type_with_role_ids
    if is_a_field_agent? && role_ids.present?
      errors[:role_ids] = :role_assign_not_allowed_for_field_agent
    end
  end

  def check_field_agent_limit
    if Account.current.reached_field_agent_limit?
      if agent_type == Account.current.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id
        errors[:agent_type] = :maximum_field_agents_reached
      end
    end
  end

  def check_ticket_search_settings
    @search_settings.each_key do |key|
      return errors[key] = :ticket_search_settings_blank if @search_settings[key].blank?
    end
    errors[:archive] = :invalid_field if @search_settings[:tickets].key?(:archive) && !archive_tickets_enabled?
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

  def archive_tickets_enabled?
    Account.current.archive_tickets_enabled?
  end

  private

    def is_a_field_agent?
      Account.current.field_service_management_enabled? && agent_type == Account.current.agent_types.find_by_name(Agent::FIELD_AGENT).agent_type_id
    end
end
