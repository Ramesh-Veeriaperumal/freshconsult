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
end

include TestCaseMethods
