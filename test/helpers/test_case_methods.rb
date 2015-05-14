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

  def construct_params unwrapped, wrapped = false
    params_hash = request_params.merge(unwrapped)
    params_hash.merge!(wrap_cname(wrapped)) if wrapped
    params_hash
  end
end

include TestCaseMethods
