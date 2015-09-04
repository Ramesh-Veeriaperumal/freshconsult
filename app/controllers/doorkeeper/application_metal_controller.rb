class Doorkeeper::ApplicationMetalController < Doorkeeper::ApplicationController
  skip_before_filter :check_privilege
end
