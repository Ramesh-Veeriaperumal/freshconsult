module TestCaseMethods
  def parse_response(response)
    JSON.parse(response)
    rescue
  end

  def with_forgery_protection
    old_value = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = old_value
  end

  def request_params
    { version: 'v2', format: :json }
  end

  def match_json(json)
    response.body.must_match_json_expression json
  end

  # pass params that are to be wrapped by controller name for 'wrapped'
  # and the rest like 'id' for 'unwrapped'
  def construct_params(unwrapped, wrapped = false)
    params_hash = request_params.merge(unwrapped)
    params_hash.merge!(wrap_cname(wrapped)) if wrapped
    params_hash
  end

  def add_content_type
    @headers ||= {}
    @headers['CONTENT_TYPE'] = 'application/json'
  end

  def other_user
    User.where('id != ?', @agent.id).first || add_new_user(@account)
  end

  def user_without_monitorships
    User.includes(:monitorships).find { |x| x.id != @agent.id && x.monitorships.blank? } || add_new_user(@account) # changed as it should have user without any monitorship
  end
end

include TestCaseMethods
