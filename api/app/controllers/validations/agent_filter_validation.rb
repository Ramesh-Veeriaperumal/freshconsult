class AgentFilterValidation < FilterValidation
  attr_accessor :state, :phone, :mobile, :email, :conditions, :only, :type, :privilege, :group_id, :include, :order_by, :order_type,
                :channel, :search_term

  CHECK_PARAMS_SET_FIELDS = ['only', 'channel', 'search_term'].freeze

  validates :state, custom_inclusion: { in: AgentConstants::STATES }
  validates :email, data_type: { rules: String }
  validates :email, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address', allow_nil: true }

  validates :phone, :mobile, data_type: { rules: String }
  validates :only, custom_inclusion: { in: AgentConstants::ALLOWED_ONLY_PARAMS }, data_type: { rules: String }

  validates :type, allow_nil: false, custom_inclusion: { in: proc { |x| x.account_agent_types }, data_type: { rules: String } }
  validates :group_id, allow_nil: false, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }, unless: :only_availability?
  validates :group_id, allow_nil: false, data_type: { rules: String }, if: :only_availability?
  validates :include, custom_inclusion: { in: AgentConstants::ALLOWED_INCLUDE_PARAMS }, data_type: { rules: String }
  validates :order_by, custom_inclusion: { in: AgentConstants::AGENTS_ORDER_BY }
  validates :order_type, custom_inclusion: { in: AgentConstants::AGENTS_ORDER_TYPE }
  validate :validate_privilege
  validates :channel, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field,
                                        message_options: { attribute: 'channel', feature: :omni_channel_routing } },
                      unless: -> { Account.current.omni_channel_routing_enabled? }
  validates :channel, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field,
                                        message_options: { attribute: 'channel', feature: :omni_agent_availability_dashboard } },
                      unless: -> { Account.current.omni_agent_availability_dashboard_enabled? }
  validates :search_term, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field,
                                            message_options: { attribute: 'search_term', feature: :omni_channel_routing } },
                          unless: -> { Account.current.omni_channel_routing_enabled? }
  validates :search_term, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field,
                                            message_options: { attribute: 'search_term', feature: :omni_agent_availability_dashboard } },
                          unless: -> { Account.current.omni_agent_availability_dashboard_enabled? }
  validates :only, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field,
                                     message_options: { attribute: 'only=availability', feature: :omni_channel_routing } },
                   if: -> { only_availability? && !Account.current.omni_channel_routing_enabled? }
  validates :only, custom_absence: { message: :require_feature_for_attribute, code: :inaccessible_field,
                                     message_options: { attribute: 'only=availability', feature: :omni_agent_availability_dashboard } },
                   if: -> { only_availability? && !Account.current.omni_agent_availability_dashboard_enabled? }
  validates :channel, custom_absence: { message: :require_availability, code: :inaccessible_field,
                                        message_options: { param: :channel } }, unless: :only_availability?
  validates :search_term, custom_absence: { message: :require_availability, code: :inaccessible_field,
                                            message_options: { param: :search_term } }, unless: :only_availability?
  validates :channel, custom_inclusion: { in: OmniChannelRouting::Constants::OMNI_CHANNELS }, data_type: { rules: String }
  validates :search_term, allow_nil: false, data_type: { rules: String }
  validate :validate_omniroute_params, if: :only_availability?

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

  def only_availability?
    @only_availability ||= (safe_send(:only) == 'availability')
  end

  def validate_omniroute_params
    errors[:channel] = :require_group_id if @channel && !@group_id
    errors[:group_id] = :require_channel if @group_id && !@channel
  end
end
