class Channel::Freshcaller::Search::CustomersController < Ember::Search::CustomersController
  include ::Freshcaller::JwtAuthentication
  include ::Freshcaller::CallConcern
  skip_before_filter :check_privilege, :check_day_pass_usage_with_user_time_zone
  before_filter :reset_current_user
  before_filter :custom_authenticate_request

  def results
    super
  end

  def reset_current_user
      User.reset_current_user
    end
end
