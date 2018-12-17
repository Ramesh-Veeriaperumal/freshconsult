class ShopifyListingController < ApplicationController

  INTEGRATION_URL = URI.parse(AppConfig['integrations_url'][Rails.env]).host

  layout :choose_layout

  skip_filter :select_shard
  skip_before_filter :check_privilege, :verify_authenticity_token
  skip_before_filter :set_current_account, :redactor_form_builder, :check_account_state, :set_time_zone,
                    :check_day_pass_usage, :set_locale
  before_filter :get_base_domain

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
      account = Account.find_by_full_domain(account)
      if account.nil?
        render("/errors/invalid_domain", :layout => false)
      else
        shop_name = params[:shop]
        redirect_to AppConfig['integrations_url'][Rails.env] + "/auth/shopify?shop=#{shop_name}&origin=id%3D#{account.id}"
      end
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

end