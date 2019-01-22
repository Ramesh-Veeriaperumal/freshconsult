class ShopifyListingController < ApplicationController

  INTEGRATION_URL = URI.parse(AppConfig['integrations_url'][Rails.env]).host
  DEFAULT_SCOPE = OmniAuth::Strategies::Shopify::DEFAULT_SCOPE

  layout :choose_layout

  skip_filter :select_shard
  skip_before_filter :check_privilege, :verify_authenticity_token
  skip_before_filter :set_current_account, :redactor_form_builder, :check_account_state, :set_time_zone,
                    :check_day_pass_usage, :set_locale
  before_filter :get_base_domain


  def send_approval_request
    redirect_to shopify_url
  end

  def show
    if check_params?
      @hmac = params[:hmac]
      @shop = params[:shop]
      @timestamp = params[:timestamp]
    else
      render_404
    end
  end

  def verify_domain_shopify
    if params[:account].to_s.blank?
      render("/errors/invalid_domain", :layout => false)
    else
      account = params[:account].include?(@base_domain) ? params[:account] : params[:account] + @base_domain
      redirect_to get_redirect_url(account)
    end
  end

  private
    def get_base_domain
      @base_domain = ".#{AppConfig["base_domain"][Rails.env]}"
    end

    def choose_layout
      'shopify_listing'
    end

    def check_params?
      return true if (params[:hmac] && params[:shop])
    end

    def get_redirect_url(full_domain)
      protocol = Rails.env.development? ? 'http' : 'https'
      port = Rails.env.development? ? ':4200' : ''
      landing_path = '/integrations/marketplace/shopify/landing'
      shop_name = params[:shop]
      redirect_domain = "#{protocol}://#{full_domain}#{port}#{landing_path}?remote_id=#{shop_name}"
    end

    def shopify_url
      hmac = params[:hmac]
      shop = params[:shop]
      callback_url = "#{AppConfig['integrations_url'][Rails.env]}/shopify_landing&scope=#{DEFAULT_SCOPE}"
      token = Integrations::OAUTH_CONFIG_HASH["shopify"]["consumer_token"]
      "https://#{shop}/admin/oauth/request_grant?client_id=#{token}&redirect_uri=#{callback_url}&state=#{hmac}"
    end

end