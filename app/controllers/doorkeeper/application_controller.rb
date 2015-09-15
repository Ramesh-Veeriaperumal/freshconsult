class Doorkeeper::ApplicationController < ::ApplicationController
  include Doorkeeper::Helpers::Controller
  layout 'marketplace/oauthpage'

  helper 'doorkeeper/dashboard'
end
