class Integrations::WidgetsController < ApplicationController
  skip_before_filter :check_privilege, :verify_authenticity_token
end
