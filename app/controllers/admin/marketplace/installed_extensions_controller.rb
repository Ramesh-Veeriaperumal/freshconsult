class Admin::Marketplace::InstalledExtensionsController < Admin::AdminController
  include Marketplace::ApiMethods
  include Marketplace::ApiUtil
  include Marketplace::HelperMethods
  include Marketplace::InstExtControllerMethods
  include DataVersioning::ExternalModel

  before_filter { |c| c.requires_feature :marketplace }
  before_filter :verify_oauth_callback , :only => [:oauth_callback]
  before_filter :extension, :only => [:install, :reinstall, :uninstall, :oauth_callback, :new_configs, :new_oauth_iparams, :edit_oauth_iparams]
  before_filter :extension_has_config?, :only => [:new_configs]
  before_filter :verify_billing_info, :only => [:install, :reinstall], :if => :account_subscription_verify?
  after_filter  :update_timestamp, only: [:install, :reinstall, :uninstall, :enable, :disable, :update_config]

  rescue_from Exception, :with => :mkp_exception

  def new_configs
    params[:page] = "iparams"
    if platform_version == Marketplace::Constants::PLATFORM_VERSIONS_BY_ID[:v2]
      configs_page_v2
    else
      extn_configs = extension_configs
      render_error_response && return if error_status?(extn_configs)
      @configs = extn_configs.body
    end

    render 'admin/marketplace/installed_extensions/configs'
  end

  # Gets called only for the v2 apps with ouath_iparams.
  def new_oauth_iparams
    oauth_iparams_page
    params[:page] = "oauth_iparams"
    render 'admin/marketplace/installed_extensions/configs'
  rescue => e
    render_error_response
  end

  # Gets called When oauth app reauthorize and is having oauth iparams.
  def edit_oauth_iparams
    params[:page] = "oauth_iparams"
    acc_config = account_configs
    render_error_response && return if error_status?(acc_config)
    oauth_iparams_page
    @configs = acc_config.body['oauth_iparams']
    render 'admin/marketplace/installed_extensions/configs'
  rescue => e
    render_error_response
  end

  def edit_configs
    params[:page] = 'iparams'
    acc_config = account_configs
    render_error_response && return if error_status?(acc_config)
    if platform_version == Marketplace::Constants::PLATFORM_VERSIONS_BY_ID[:v2]
      extension_v2
      configs_page_v2
      @configs = acc_config.body
    else
      extension
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
    install_ext = install_extension(install_params(account_configs_values))
    flash[:notice] = t('marketplace.install_action.success') if install_ext.status == 200
    render :json => install_ext.body, :status => install_ext.status
  end

  def oauth_install
    render :json => { :redirect_url => oauth_handshake }
  end

  def edit_oauth_configs
    render :json => { :redirect_url => oauth_handshake }
  end

  def oauth_callback
    redirect_url = "/integrations/applications/##{params[:extension_id]}_configs"
    referer_host = request.env['HTTP_REFERER'] ? URI.parse(request.env['HTTP_REFERER']).host : ''
    redirect_url = platform_version == Marketplace::Constants::PLATFORM_VERSIONS_BY_ID[:v2] ? "/a#{redirect_url}" : redirect_url
    redirect_to redirect_url
  end

  def reinstall
    prev_version_addon = previous_version_addon
    return unless prev_version_addon
    update_ext(install_params(account_configs_values).deep_merge(prev_version_addon))
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
    update_ext(update_config_params(JSON.parse(params[:configs])))
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

  def update_params
    {
      :configs => JSON.parse(params[:configs]),
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
                  .merge(offline_subscription? ? {} : paid_app_params)
    if configs.present? && configs[:oauth_configs].present?
      inst_params[:oauth_configs] = configs[:oauth_configs]
      inst_params[:configs].except!(:oauth_configs)
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

    def update_timestamp
      update_version_timestamp(Marketplace::Constants::MARKETPLACE_VERSION_MEMBER_KEY)
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
        redirect_url = platform_version == Marketplace::Constants::PLATFORM_VERSIONS_BY_ID[:v2] ?
                        '/a/integrations/applications/' : '/integrations/applications/'
        redirect_to(redirect_url, :flash => {:notice => notice_message}) and return
      end
    end

    def account_configs_values
      if is_oauth_app?(@extension)
        account_tokens = fetch_tokens
        if error_status?(account_tokens)
          notice_message = t('marketplace.install_action.failure')
        end
      end
      configs = params[:configs].blank? ? {} : JSON.parse(params[:configs])
      oauth_configs = is_oauth_app?(@extension) ? { :oauth_configs => account_tokens.body } : {}
      configs = configs.merge(is_oauth_app?(@extension) ? { :oauth_configs => account_tokens.body } : {})
      configs
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
