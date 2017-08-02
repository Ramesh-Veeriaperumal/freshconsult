class Admin::Marketplace::InstalledExtensionsController <  Admin::AdminController
  include Marketplace::ApiMethods
  include Marketplace::ApiUtil
  include Marketplace::HelperMethods
  include Marketplace::InstExtControllerMethods

  before_filter :verify_oauth_callback , :only => [:oauth_callback]
  before_filter :extension, :only => [:install, :reinstall, :uninstall, :oauth_callback, :new_configs, :edit_configs]
  before_filter :extension_has_config?, :only => [:new_configs, :edit_configs]
  before_filter :verify_billing_info, :only => [:install, :reinstall], :if => :paid_app?

  rescue_from Exception, :with => :mkp_exception

  def new_configs
    if platform_version == Marketplace::Constants::PLATFORM_VERSIONS_BY_ID[:v2]
      configs_page_v2
    else
      extn_configs = extension_configs
      render_error_response && return if error_status?(extn_configs)
      @configs = extn_configs.body
    end

    render 'admin/marketplace/installed_extensions/configs'
  end

  def edit_configs
    acc_config = account_configs
    render_error_response && return if error_status?(acc_config)
    if platform_version == Marketplace::Constants::PLATFORM_VERSIONS_BY_ID[:v2]
      configs_page_v2
      @configs = acc_config.body
    else
      extn_configs = extension_configs
      render_error_response && return if error_status?(extn_configs)
      @configs = account_configurations(extn_configs.body, acc_config.body)
    end
    
    render 'admin/marketplace/installed_extensions/configs'
  end

  def iframe_configs
    iframe_details = iframe_settings
    render_error_response and return if error_status?(iframe_details)
    iframe_url = iframe_details.body["url"]
    render_error_response(:bad_request) and return if iframe_url.blank?
    iframe_params = get_iframe_params(iframe_details.body)
    encrypted_iframe_params = iframe_token(iframe_details.body, iframe_params)
    return unless encrypted_iframe_params
    @iframe_url = Liquid::Template.parse(iframe_url).render({"encryptedParams" => encrypted_iframe_params})
    render 'admin/marketplace/installed_extensions/iframe_configs', :status => iframe_details.status
  end

  def install
    install_ext = install_extension(install_params(params[:configs]))
    flash[:notice] = t('marketplace.install_action.success') if install_ext.status == 200
    render :json => install_ext.body, :status => install_ext.status
  end

  def oauth_configs
    $redis_mkp.mapped_hmset(redis_key, params['configs']) unless params['configs'].blank?
    callback_path = "/admin/marketplace/installed_extensions/#{params[:extension_id]}/#{params[:version_id]}/oauth_callback"
    if params['upgrade']
      callback_path = CGI.escape("#{callback_path}?upgrade=true&installed_version=#{params[:installed_version]}")
    end
    oauth_handshake(callback_path)
  end

  def edit_oauth_configs
    callback_path = "/admin/marketplace/installed_extensions/#{params[:extension_id]}/#{params[:version_id]}/oauth_callback"
    oauth_handshake(callback_path, true)
  end

  def oauth_callback
    config_params = {}
    config_params = $redis_mkp.hgetall(redis_key)
    config_params["oauth_configs"] = {}
    account_tokens = fetch_tokens
    if error_status?(account_tokens)
      notice_message = t('marketplace.install_action.failure')
    else
      config_params["oauth_configs"].merge!(account_tokens.body)
      if params['upgrade']
        update_ext = update_extension(install_params(config_params).deep_merge(previous_version_addon))
      else
        install_ext = install_extension(install_params(config_params))
      end
      notice_message = t('marketplace.install_action.success')
    end
    redirect_to('/integrations/applications', :flash => {:notice => notice_message})
  end

  def reinstall
    prev_version_addon = previous_version_addon
    return unless prev_version_addon
    update_ext(install_params(params[:configs]).deep_merge(prev_version_addon))
  end

  def uninstall
    uninstall_ext = uninstall_extension(uninstall_params)
    render :json => uninstall_ext.body, :status => uninstall_ext.status
  end

  def enable
    update_ext = update_extension(enable_params)
    render :nothing => true, :status => update_ext.status
  end

  def disable
    update_ext = update_extension(disable_params)
    render :nothing => true, :status => update_ext.status
  end

  def update_config
    update_ext(update_config_params(params[:configs]))
  end

  def app_status
    resp = fetch_app_status
    if resp.status == 202
      render :nothing => true, :status => resp.status
    else
      flash[:notice] = t("marketplace.#{params[:event]}_action.success") if params[:event].present?
      render :json => resp.body, :status => resp.status
    end
  end

  private

  def update_ext(update_ext_params)
    update_ext = update_extension(update_ext_params)
    flash[:notice] = t('marketplace.update_action.success') if update_ext.status == 200
    render :json => update_ext.body, :status => update_ext.status
  end

  def oauth_handshake(callback, is_reauthorize = false)
    oauth_callback_url =  "#{request.protocol}#{request.host_with_port}" + callback
    mkp_oauth_endpoint = Marketplace::ApiEndpoint::ENDPOINT_URL[:oauth_install] % {
      :product_id => PRODUCT_ID.to_s,
      :account_id => Account.current.id.to_s,
      :version_id => params[:version_id]
    }
    reauth_param = is_reauthorize ? "&edit_oauth=true&installed_extn_id=" + params[:installed_extn_id] : ""
    redirect_url = "#{MarketplaceConfig::MKP_OAUTH_URL}/" + mkp_oauth_endpoint + "?callback=" + oauth_callback_url + reauth_param
    redirect_to redirect_url + "&fdcode=" + CGI.escape(generate_md5_digest(redirect_url, MarketplaceConfig::API_AUTH_KEY))
  end

  def update_params
    {
      :configs => params[:configs],
      :version_id => params[:version_id]
    }
  end

  def redis_key
    "freshapps_" + Account.current.id.to_s + "_" + params[:version_id]
  end

  def install_params(configs)
    inst_params = {
                    :extension_id => params[:extension_id],
                    :version_id => params[:version_id],
                    :configs => configs,
                    :enabled => Marketplace::Constants::EXTENSION_STATUS[:enabled],
                    :type => @extension['type'],
                    :options => @extension['page_options'],
                    :events => @extension['events'] || {},
                    :account_full_domain => current_account.full_domain
                  }
                  .merge(params[:installed_version] ? {:installed_version => params[:installed_version]} : {})
                  .merge(paid_app_params)
    if configs.present? && configs["oauth_configs"].present?
      inst_params[:oauth_configs] = configs["oauth_configs"]
      inst_params[:configs].except!("oauth_configs")
    end
    inst_params
  end

    def uninstall_params
      { :extension_id => params[:extension_id],
        :version_id => params[:version_id],
        :events => @extension['events'] || {},
        :account_full_domain => current_account.full_domain
      }.merge(paid_app_params)
    end

    def enable_params
      { :extension_id => params[:extension_id],
        :version_id => params[:version_id],
        :enabled => Marketplace::Constants::EXTENSION_STATUS[:enabled] }
    end

    def disable_params
      { :extension_id => params[:extension_id],
        :version_id => params[:version_id],
        :enabled => Marketplace::Constants::EXTENSION_STATUS[:disabled] }
    end

    def update_config_params(configs)
      config_params = {
        :extension_id => params[:extension_id],
        :version_id => params[:version_id], 
        :configs => configs }
      if configs.present? && configs["oauth_configs"].present?
        config_params[:oauth_configs] = configs["oauth_configs"]
        config_params[:configs].except!("oauth_configs")
      end
      config_params
    end

    def account_configurations(configs, acc_configs)
      @account_configurations = []
      configs.each do |config|
        if config['field_type'] == Marketplace::Constants::FORM_FIELD_TYPE[:text]
          config['default_value'] = acc_configs[config['name']]
        else
          config['default_value'].delete(acc_configs[config['name']])
          config['default_value'].unshift(acc_configs[config['name']])
        end
        @account_configurations << config
      end
      @account_configurations
    end

    def verify_billing_info
      unless current_account.active? && current_account.subscription.card_number.present?
        render :nothing => true, :status => 400
      end
    end

    def verify_oauth_callback
      if params[:code].blank?
        if params[:is_reauthorize]
          notice_message = t('marketplace.install_action.success')
        else
          notice_message = t('marketplace.install_action.auth_error')
        end
        redirect_to('/integrations/applications', :flash => {:notice => notice_message}) and return
      end
    end

    def previous_version_addon
      installed_extension = installed_extension_details
      render_error_response and return false if error_status?(installed_extension)
      installed_version_id = installed_extension.body['version_id']

      if installed_version_id != params[:version_id]
        installed_version = version_details(installed_version_id)
        render_error_response and return false if error_status?(installed_version)

        addon_id = installed_version.body['addon_id']
        return { :billing => { :previous_version_addon => addon_id }.merge(
                 paid_app? ? {} : account_params) } if addon_id
      end
      return {}
    end
end
