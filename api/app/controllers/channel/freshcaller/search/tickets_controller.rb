class Channel::Freshcaller::Search::TicketsController < Ember::Search::TicketsController
  include ::Freshcaller::JwtAuthentication
  include ::Freshcaller::CallConcern
  skip_before_filter :check_privilege, :set_current_account, :check_day_pass_usage_with_user_time_zone
  before_filter :reset_current_user
  before_filter :filter_current_user, only: [:results]
  before_filter :custom_authenticate_request

  def results
    super
  end

 private

  def filter_current_user
    @load_current_user = true
  end

  def reset_current_user
    User.reset_current_user
  end
end