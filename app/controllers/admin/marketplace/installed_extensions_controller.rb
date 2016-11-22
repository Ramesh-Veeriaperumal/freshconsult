class Admin::Marketplace::InstalledExtensionsController <  Admin::AdminController
  include Marketplace::ApiMethods
  include Marketplace::ApiUtil

  rescue_from Exception, :with => :mkp_exception

  def new_configs
    extn_configs = extension_configs
    render_error_response and return if error_status?(extn_configs)
    @configs = extn_configs.body
    render 'admin/marketplace/installed_extensions/configs', :status => extn_configs.status
  end
 
  def edit_configs
    extn_configs = extension_configs
    render_error_response and return if error_status?(extn_configs)

    acc_config = account_configs
    render_error_response and return if error_status?(acc_config)

    @configs = account_configurations(extn_configs.body, acc_config.body)
    render 'admin/marketplace/installed_extensions/configs', :status => extn_configs.status
  end

  def install
    extn_details = extension_details
    render_error_response and return if error_status?(extn_details)

    install_ext = install_extension(install_params(extn_details.body, params[:configs]))
    flash[:notice] = t('marketplace.install_action.success')
    render :nothing => true, :status => install_ext.status 
  end

  def oauth_configs
    $redis_mkp.mapped_hmset(redis_key, params['configs']) unless params['configs'].blank?
    callback_path = "/admin/marketplace/installed_extensions/#{params[:extension_id]}/#{params[:version_id]}/oauth_callback"
    if params['upgrade']
      callback_path = "#{callback_path}?upgrade=true"
    end
    oauth_handshake(callback_path)
  end

  def edit_oauth_configs
    callback_path = "/admin/marketplace/installed_extensions/#{params[:extension_id]}/#{params[:version_id]}/oauth_callback"
    oauth_handshake(callback_path, true)
  end

  def oauth_callback
    if params[:code].blank?
      if params[:is_reauthorize]
        notice_message = t('marketplace.install_action.success')
      else
        notice_message = t('marketplace.install_action.auth_error')
      end
      redirect_to('/integrations/applications', :flash => {:notice => notice_message}) and return
    end
    extn_details = extension_details
    render_error_response and return if error_status?(extn_details)
    config_params = {}
    config_params = $redis_mkp.hgetall(redis_key)
    account_tokens = fetch_tokens
    if error_status?(account_tokens)
      notice_message = t('marketplace.install_action.failure')
    else
      if params['upgrade']
        update_ext = update_extension(install_params(extn_details.body, config_params.merge(account_tokens.body)))
      else
        install_ext = install_extension(install_params(extn_details.body, config_params.merge(account_tokens.body)))
      end
      notice_message = t('marketplace.install_action.success')
    end
    redirect_to('/integrations/applications', :flash => {:notice => notice_message})
  end

  def reinstall
    extn_details = extension_details
    render_error_response and return if error_status?(extn_details)
    acc_config = account_configs
    render_error_response and return if error_status?(acc_config)
    params[:configs]['access_token'] = acc_config.body['access_token'] if acc_config.body['access_token']
    params[:configs]['refresh_token'] = acc_config.body['refresh_token'] if acc_config.body['refresh_token']
    update_ext = update_extension(install_params(extn_details.body, params[:configs]))
    flash[:notice] = t('marketplace.update_action.success')
    render :nothing => true, :status => update_ext.status
  end

  def uninstall
    uninstall_ext = uninstall_extension(uninstall_params)
    render :nothing => true, :status => uninstall_ext.status
  end

  def enable
    update_ext = update_extension(enable_params)
    render :nothing => true, :status => update_ext.status
  end

  def disable
    update_ext = update_extension(disable_params)
    render :nothing => true, :status => update_ext.status
  end

  private

  def oauth_handshake(callback, is_reauthorize = false)
    oauth_callback_url =  "#{request.protocol}#{request.host_with_port}" + callback
    mkp_oauth_endpoint = Marketplace::ApiEndpoint::ENDPOINT_URL[:oauth_install] % {
      :product_id => PRODUCT_ID.to_s,
      :account_id => Account.current.id.to_s,
      :version_id => params[:version_id]
    }
    shard = ShardMapping.lookup_with_account_id(Account.current.id)
    reauth_param = is_reauthorize ? "&edit_oauth=true&account_pod=" + shard.pod_info + "&installed_extn_id=" + params[:installed_extn_id] : ""
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

  def install_params(extn_details, configs)
      { :extension_id => params[:extension_id],
        :version_id => params[:version_id],
        :configs => configs,
        :enabled => Marketplace::Constants::EXTENSION_STATUS[:enabled],
        :type => extn_details['type'],
        :options => extn_details['page_options'],
      }
    end

    def uninstall_params
      { :extension_id => params[:extension_id]
      }
    end

    def enable_params
      { :extension_id => params[:extension_id],
        :enabled => Marketplace::Constants::EXTENSION_STATUS[:enabled] }
    end

    def disable_params
      { :extension_id => params[:extension_id],
        :enabled => Marketplace::Constants::EXTENSION_STATUS[:disabled] }
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
end
