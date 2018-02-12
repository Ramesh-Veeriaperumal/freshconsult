class Channel::Freshcaller::ContactsController < Ember::ContactsController
  include ::Freshcaller::JwtAuthentication
  include ::Freshcaller::CallConcern
  skip_before_filter :check_privilege, :set_current_account, :check_day_pass_usage_with_user_time_zone, :check_falcon
  before_filter :reset_current_user
  before_filter :filter_current_user, only: [:activities]
  before_filter :custom_authenticate_request

  def activities
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