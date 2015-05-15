module TestCaseMethods
  def parse_response(response)
    JSON.parse(response)
    rescue
  end

  def with_forgery_protection
    _old_value = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = _old_value
  end

  def request_params
    {:version => "v2", :format => :json}
  end

  def match_json json
    response.body.must_match_json_expression json
  end

  # pass params that are to be wrapped by controller name for 'wrapped'
  # and the rest like 'id' for 'unwrapped'
  def construct_params unwrapped, wrapped = false
    params_hash = request_params.merge(unwrapped)
    params_hash.merge!(wrap_cname(wrapped)) if wrapped
    params_hash
  end

  def other_user
    User.where("id != ?", @agent.id).first || add_new_user(@account)
  end

  def user_without_monitorships
    User.includes(:monitorships).select{|x| x.id != @agent.id && x.monitorships.blank?}.first || create_dummy_customer
  end
end

include TestCaseMethods
