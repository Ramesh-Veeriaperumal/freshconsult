class Integrations::Marketplace::ShopifyController < Integrations::Marketplace::LoginController

  include Integrations::OauthHelper

  skip_filter :select_shard, :only => [:signup]
  around_filter :select_shard_marketplace, :only => [:signup]

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:signup, :receive_webhook]

  skip_before_filter :set_current_account, :check_account_state, :set_time_zone, :check_day_pass_usage, :set_locale, :only => [:signup, :landing, :receive_webhook]

  before_filter :verify_hmac, :only => [:receive_webhook]

  def install
    shop_name = params[:configs][:shop_name].include?(".myshopify.com") ? params[:configs][:shop_name] : params[:configs][:shop_name] + ".myshopify.com"
    redirect_to AppConfig['integrations_url'][Rails.env] + "/auth/shopify?shop=#{shop_name}&origin=id%3D#{current_account.id}"
  end

  def receive_webhook
    installed_app = current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:shopify]).first
    response = { :message => "App not found" }
    shop_name = request.headers['X-Shopify-Shop-Domain']
    if installed_app.present? && shop_name == installed_app.configs_shop_name && params['webhook_verifier'] == installed_app.configs_webhook_verifier
      installed_app.destroy
      response = { :message => "App removed" }
    end
    render :status => :ok, :json => response
  end

  def create
    begin
      load_installed_application
      raise "Can't edit" if @installed_application.persisted?
      webhook_verifier = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, @installed_application.configs_shop_name, Time.now.to_i.to_s)
      @installed_application.configs[:inputs]["webhook_verifier"] = webhook_verifier
      if @installed_application.save!
        flash[:notice] = t(:'flash.application.install.success')
      else
        flash[:error] = t(:'flash.application.install.error')
      end
    rescue => e
      Rails.logger.error "Problem in installing shopify application. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      flash[:error] = t(:'flash.application.install.error')
    end
    redirect_to integrations_applications_path
  end

  def signup
    map_remote_user
  end

  def landing
    installed_app = current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:shopify]).first
    shop = params[:shop]
    if shop.blank?
      remote_integ_map = Integrations::ShopifyRemoteUser.where(:account_id => current_account.id).first
      if remote_integ_map.present?
        shop = remote_integ_map.remote_id
      end
    end
    if installed_app.present? || shop.blank?
      redirect_to integrations_applications_url
    else
      redirect_to AppConfig['integrations_url'][Rails.env] + "/auth/shopify?shop=#{shop}&origin=id%3D#{current_account.id.to_s}"
    end
  end

  private

    def select_shard_marketplace(&block)
      set_data
      if @account_id
        Sharding.select_shard_of(@account_id) do
          yield
        end
      else
        yield
      end
    end

    def set_data
      unless valid_signature?
        logger.debug "Authentication failed....delivering error page"
        raise ActionController::RoutingError, "Not Found"
      end

      data = Hash.new
      data['email'] = nil
      data['remote_id'] = params[:shop]
      data['domain'] = params[:shop].gsub('.myshopify.com', '')
      data['user_name'] = ''
      data['account_name'] = ''
      data['email_not_reqd'] = true
      data['app'] = Integrations::Constants::APP_NAMES[:shopify]

      initialize_attr(data)
    end

    def valid_signature?
      signature = params[:hmac]
      timestamp = params[:timestamp]

      return false unless signature && timestamp

      secret = Integrations::OAUTH_CONFIG_HASH[Integrations::Constants::APP_NAMES[:shopify]]['consumer_secret']
      signature_params = { :shop => params[:shop], :timestamp => timestamp }
      encoded_sign_params = signature_params.map{|k,v| "#{URI.escape(k.to_s, '&=%')}=#{URI.escape(v.to_s, '&%')}"}.sort.join('&')
      calculated_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA256.new, secret, encoded_sign_params)
      Rack::Utils.secure_compare(calculated_signature, signature)
    end

    def load_installed_application
      @installing_application = Integrations::Application.find_by_name(Integrations::Constants::APP_NAMES[:shopify])
      @installed_application = current_account.installed_applications.find_by_application_id(@installing_application)
      if @installed_application.blank?
        @installed_application = current_account.installed_applications.build(:application => @installing_application)
        @installed_application.configs = { :inputs => {} }
      end
      @installed_application.configs[:inputs] = get_app_configs
    end

    def get_app_configs
      key_options = { :account_id => current_account.id, :provider => "shopify" }
      kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options))
      kv_store.group = :integration
      app_config = JSON.parse(kv_store.get_key)
      raise "OAuth Token is nil" if app_config["oauth_token"].nil?
      app_config
    end

    def verify_hmac
      signature = request.headers['X-Shopify-Hmac-Sha256']
      secret = Integrations::OAUTH_CONFIG_HASH[Integrations::Constants::APP_NAMES[:shopify]]['consumer_secret']
      calculated_signature = Base64.strict_encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), secret, request.raw_post))
      unless Rack::Utils.secure_compare(calculated_signature, signature)
        render :status => 200, :json => { :message => "HMAC verification failed" } and return
      end
    end

end
