module Admin::Marketplace::MarketplaceInstallHelper
include FalconHelperMethods

  def generate_install_btn
    _btn = ""
    if is_external_app?
      _btn << %(<a href="#{install_url}" class="btn btn-default btn-primary install-app" 
                target='_blank' rel="noreferrer"> #{install_btn_text} </a>)
    elsif !installed? && is_ni?
      _btn = ni_install_btn
    elsif is_iframe_app?(@extension) && installed?
      _btn << %(<a class="btn btn-default btn-primary install-app #{install_btn_class}" 
                data-method="put" data-url="#{install_url}"> #{install_btn_text} </a>)
    elsif @is_oauth_app
      _btn << link_to(install_btn_text, '#', 'data-url' => install_url, :id => 'oauth_link',
              :class => "btn btn-default btn-primary install-app #{install_btn_class}")
      _btn << link_to(install_btn_text, '#', 'data-url' => oauth_settings_url,
              :class => "btn btn-default btn-primary install-app hide install-form-btn")
    else
      _btn << link_to(install_btn_text, '#', 'data-url' => install_url,
              :class => "btn btn-default btn-primary install-app #{install_btn_class}")
    end
    _btn.html_safe
  end

  def generate_buy_app_btn
    _btn = ""
    _btn << %(<a class="btn btn-default btn-primary buy-app" 
              data-url="#{payment_info_admin_marketplace_extensions_path(@extension['extension_id'])}" 
              data-install-url="#{install_url}" >
              <p class="buy-app-btn"> #{t('marketplace.buy_app')} </p>
              <p class="app-price"> #{t('marketplace.app_price',
                :price => format_amount(addon_details['price'], addon_details['currency_code']),
                :addon_type => addon_type)} </p>
              </a>)
    if @is_oauth_app
     _btn << link_to(install_btn_text, '#', 'data-url' => oauth_settings_url,
            :class => "btn btn-default btn-primary install-app hide install-form-btn")
    end
    _btn
  end

  def ni_install_btn
    _btn = ""
    if @extension['name'] == Integrations::Constants::APP_NAMES[:quickbooks]
      _btn << %(
        <div class="text-center" style="margin-top:2px;">
          <ipp:connectToIntuit></ipp:connectToIntuit>
        </div>
        <script src="https://js.appcenter.intuit.com/Content/IA/intuit.ipp.anywhere-1.3.2.js"></script>
        <script type="text/javascript">
          var qbInterval = setInterval(function(){ 
            if(typeof intuit != "undefined"){
              intuit.ipp.anywhere.setup({
                grantUrl: "#{AppConfig['integrations_url'][Rails.env]}/auth/quickbooks?origin=id%3D#{current_account.id}",
                datasources: {
                  quickbooks : true
                }
              });  
              clearInterval(qbInterval);
            }
          }, 700);
        </script>
        )
    elsif @extension['name'] == Integrations::Constants::APP_NAMES[:slack_v2]
      on_click_url = falcon_redirect_check("/integrations/slack_v2/oauth")
      _btn << %(<form id="nativeapp-form" action="#{install_url}" method="post" target="_top"> </form>)
      _btn << %(
        <a href="javascript:;" onclick="#{on_click_url}" class="install-app #{ni_install_btn_class}"><img alt="Add to Slack" src="https://platform.slack-edge.com/img/add_to_slack.png" style="padding-top: 10px;padding-left: 10px;width: 139px; height: 40px;"></a>
      )
    
    elsif [Integrations::Constants::APP_NAMES[:microsoft_teams], Integrations::Constants::APP_NAMES[:google_hangout_chat]].include?(@extension['name'])
      on_click_url = on_click_url(@extension['name'])
      _btn << %(<form id="nativeapp-form" action="#{install_url}" method="post" target="_top"> </form>)
      _btn << %(
        <a href="javascript:;" onclick="#{on_click_url}" class="btn btn-default btn-primary install-app #{ni_install_btn_class}">#{install_btn_text}</a>
      )
    elsif Integrations::Constants::FALCON_ENABLED_OAUTH_APPS.include?(@extension['name'])
      _btn << link_to(install_btn_text, install_url, :method => :post, :target => '_top',
              :class => "btn btn-default btn-primary install-app #{ni_install_btn_class}").html_safe
    else
      _btn << link_to(install_btn_text, install_url, :method => :post,
              :class => "btn btn-default btn-primary install-app #{ni_install_btn_class}").html_safe
    end
    _btn
  end

  def install_url
    if is_external_app?
      @extension['options']['redirect_url']
    elsif is_ni?
      install_integrations_marketplace_app_path(@extension['name'])
    elsif is_iframe_app?(@extension)
      if !installed? || !plug_installed_in_platform?
        admin_marketplace_installed_extensions_iframe_configs_path(@extension['extension_id'],
          @extension['version_id']) + '?' + configs_url_params
      else
        params_hash = { version_id: @extension['version_id'] }
        params_hash.merge!({installed_version: installed_version.first}) if !latest_installed?
        "#{admin_marketplace_installed_extensions_reinstall_path(@extension['extension_id'])}?#{params_hash.to_query}"
      end
    elsif is_oauth_app?(@extension)
      if has_oauth_iparams?
        admin_marketplace_installed_extensions_new_oauth_iparams_path(@extension['extension_id'], 
          @extension['version_id']) + '?' + configs_url_params(true)
      else
        admin_marketplace_installed_extensions_oauth_install_path(@extension['extension_id'], @extension['version_id'])
      end
    else
      url_params = configs_url_params
      admin_marketplace_installed_extensions_new_configs_path(@extension['extension_id'],
        @extension['version_id']) + '?' + url_params
    end
  end

  def install_btn_text
    return t('marketplace.visit_site_to_install') if is_external_app? 
    if installed?
      return t('marketplace.installed') if is_ni? || latest_installed?
      return t('marketplace.update') if plug_installed_in_platform?
    end
    return t('marketplace.install')
  end

  def install_btn_class
    if installed? && (is_ni? || (plug_installed_in_platform? && latest_installed?))
      "disabled"
    elsif is_iframe_app?(@extension)
      if installed? && plug_installed_in_platform? && !latest_installed?
        "install-btn"
      else
        "install-iframe-settings"
      end
    elsif is_oauth_app?(@extension)
      has_oauth_iparams? ? "oauth-iparams-btn" : "install-oauth-btn"
    else
      "install-form-btn"
    end
  end

  def ni_install_btn_class
    installed? ? "disabled" : "nativeapp"
  end

  def installed?
    @install_status['installed']
  end

  def installed_version
    @install_status['installed_versions'] & @extension['platform_details'][platform_version]
  end

  def plug_installed_in_platform?
    installed_version.present?
  end

  def latest_installed?
    @install_status['installed_versions'].include?(@extension['version_id'])
  end

  def app_available_in_platform?
    return false if @install_status[:unsupported]
    (is_versionable? && @extension['platform_details'][platform_version].include?(@extension['version_id'])) ||
    (!is_versionable? && @extension['platform_details'][platform_version])
  end

  def platform_not_compatible
    platform = Marketplace::Constants::PLATFORM_ID_BY_VERSION[platform_version].to_s
    %(<p class="platform_not_compatible"> #{t("marketplace.#{platform}_incompatible")} </p>).html_safe
  end

  def install_not_allowed
    %(<p class="platform_not_compatible"> #{t('marketplace.install_not_allowed')} </p>).html_safe
  end

  def oauth_settings_url
    url_params = configs_url_params(true)
    if(installed? && @install_status['installed_versions'].include?(@extension['version_id']))
      settings_url = admin_marketplace_installed_extensions_edit_configs_path(@extension['extension_id'],
      @extension['version_id'])
    else
      settings_url = admin_marketplace_installed_extensions_new_configs_path(@extension['extension_id'],
      @extension['version_id'])
    end
    settings_url = settings_url + '?' + url_params
  end

  def on_click_url(extension_name)
    if extension_name === Integrations::Constants::APP_NAMES[:microsoft_teams]
      falcon_redirect_check("/integrations/teams/oauth")
    elsif extension_name === Integrations::Constants::APP_NAMES[:google_hangout_chat]
      falcon_redirect_check("/integrations/google_hangout_chat/oauth")
    end
  end

end
