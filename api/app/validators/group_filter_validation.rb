class GroupFilterValidation < FilterValidation
  attr_accessor :group_type, :conditions, :include, :auto_assignment

  validates :group_type, custom_inclusion: { in: proc { |x| x.account_group_types} , data_type: { rules: String } }
  validate :valid_omni_channel_params, if: -> { include || auto_assignment }
  validates :include, custom_inclusion: { in: GroupConstants::ALLOWED_INCLUDE_PARAMS }, data_type: { rules: String }, if: -> { errors[:include].blank? }
  validates :auto_assignment, custom_inclusion: { in: ['true'] }, data_type: { rules: String }, if: -> { errors[:auto_assignment].blank? }

  def initialize(request_params)
    @conditions = (request_params.keys & GroupConstants::INDEX_FIELDS) - ['group_type'] + [request_params['group_type']].compact
    super(request_params, nil, true)
  end

  def account_group_types
    Account.current.group_types_from_cache.map(&:name)
  end

  def valid_omni_channel_params
    omni_channel_routing_enabled = Account.current.omni_channel_routing_enabled?
    omni_agent_availability_dashboard_enabled = Account.current.omni_agent_availability_dashboard_enabled?
    GroupConstants::OMNI_CHANNEL_FILTER_PARAMS.each do |param|
      param_value = safe_send(param)
      next unless param_value

      return require_feature_error(param, :omni_channel_routing) unless omni_channel_routing_enabled
      return require_feature_error(param, :omni_agent_availability_dashboard) unless omni_agent_availability_dashboard_enabled
    end
    errors[:auto_assignment] = :require_omni_channel_groups if auto_assignment && !include
  end

  def require_feature_error(attribute, feature)
    errors[attribute] = :require_feature_for_attribute
    error_options[attribute.to_sym] = {
      attribute: attribute.to_s,
      feature: feature
    }
  end
end
