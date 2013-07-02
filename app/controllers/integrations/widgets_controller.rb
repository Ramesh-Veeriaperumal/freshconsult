class Integrations::WidgetsController < ApplicationController
  skip_before_filter :check_privilege
end
