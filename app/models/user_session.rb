class UserSession < Authlogic::Session::Base
  params_key :k
  single_access_allowed_request_types :any
end
