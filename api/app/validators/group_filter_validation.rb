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
    unless Account.current.omni_channel_routing_enabled?
      GroupConstants::OMNI_CHANNEL_FILTER_PARAMS.each do |param|
        param_value = safe_send(param)
        next unless param_value

        errors[param] = :require_feature_for_attribute
        error_options[param.to_sym] = {
          attribute: param.to_s,
          feature: :omni_channel_routing
        }
      end
      return
    end
    errors[:auto_assignment] = :require_omni_channel_groups if auto_assignment && !include
  end
end
