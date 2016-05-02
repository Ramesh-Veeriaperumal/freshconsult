class CompanyFilterValidation < ApiValidation
  attr_accessor :name, :conditions

  def initialize(request_params, item, allow_string_param = true)
    request_params['state'] = 'all' if request_params['state'].nil?
    @conditions = (request_params.keys & CompanyConstants::INDEX_FIELDS) - ['state'] + [request_params['state']].compact
    super(request_params, item, allow_string_param)
  end
end
