class TwitterRedirectAuthController < ApplicationController
  include Redis::OthersRedis
  before_filter :check_state
  skip_before_filter :check_privilege, :verify_authenticity_token
  skip_before_filter :set_current_account, :redactor_form_builder, :check_account_state, :set_time_zone,
                     :check_day_pass_usage, :set_locale, :check_session_timeout, only: [:complete]
  skip_after_filter :set_last_active_time

  def complete
    redirect_url = host_url

    redirect_to global_url and return if redirect_url.blank?
    redirect_to redirect_url and return if params[:denied].present? || params[:oauth_verifier].blank? || params[:oauth_token].blank?
    redirect_to "#{redirect_url}?oauth_verifier=#{params[:oauth_verifier]}&oauth_token=#{params[:oauth_token]}"
  end

  private

  def check_state
    redirect_to global_url and return false if params[:state].blank? 
    true
  end

  def host_url
    state = "#{params[:state]}"
    key = "#{Social::Twitter::Constants::COMMON_REDIRECT_REDIS_PREFIX}:#{state}"

    get_others_redis_key(key)
  end

  def global_url
    "#{AppConfig['integrations_url'][Rails.env]}"
  end
end