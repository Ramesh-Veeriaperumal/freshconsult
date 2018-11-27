class GroupFilterValidation < FilterValidation
  attr_accessor :group_type, :conditions

  validates :group_type, custom_inclusion: { in: proc { |x| x.account_group_types} , data_type: { rules: String } }

  def initialize(request_params)
    @conditions = (request_params.keys & GroupConstants::INDEX_FIELDS) - ['group_type'] + [request_params['group_type']].compact
    super(request_params, nil, true)
  end

  def account_group_types
    Account.current.group_types_from_cache.map(&:name)
  end
end
