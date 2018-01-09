class FacebookRedirectAuthController < ApplicationController
  include Redis::OthersRedis
  before_filter :check_params
  skip_before_filter :check_privilege, :verify_authenticity_token
  skip_before_filter :set_current_account, :redactor_form_builder, :check_account_state, :set_time_zone,
                     :check_day_pass_usage, :set_locale, :only => [:complete]
  skip_after_filter :set_last_active_time

  def complete
    state = "#{params[:state]}"
    host_url = get_others_redis_key(state)
    failure unless host_url
    redirect_to "#{host_url}?code=#{params[:code]}"
  end

  private

  def failure
    redirect_to "#{AppConfig['integrations_url'][Rails.env]}"
  end

  def check_params
    failure unless params[:state] && params[:code]
  end
end