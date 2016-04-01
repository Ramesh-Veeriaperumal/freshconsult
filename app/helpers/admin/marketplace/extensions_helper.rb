module Admin::Marketplace::ExtensionsHelper

  include Admin::Marketplace::CommonHelper

  def install_url
    if @extension['type'] == Marketplace::Constants::EXTENSION_TYPE[:ni]
      install_integrations_marketplace_app_path(@extension['name'])
    else
      admin_marketplace_installed_extensions_new_configs_path(@extension['extension_id'],
        @extension['version_id']) + '?' + configs_url_params(@extension, @install_status)
    end
  end

  def install_btn_text
    if @install_status['installed']
      if @install_status['installed_version'] == @extension['version_id']
        t('marketplace.installed')
      else
        t('marketplace.update')
      end
    else
      t('marketplace.install')
    end
  end

  def install_btn_class
    if @install_status['installed'] && @install_status['installed_version'] == @extension['version_id']
      "disabled"
    elsif @extension['type'] == Marketplace::Constants::EXTENSION_TYPE[:ni]
      "nativeapp"
    else
      "install-form-btn"
    end
  end


  def install_btn(extension, install_status)
    @extension = extension
    @install_status = install_status
    generate_install_btn
  end


  def generate_install_btn
    _btn = ""
    if !@install_status['installed'] && @extension['type'] == Marketplace::Constants::EXTENSION_TYPE[:ni]
      _btn = ni_install_btn
    else
       _btn << %(<a class="btn btn-default btn-primary install-app #{install_btn_class}" 
                 data-url="#{install_url}"> #{install_btn_text} </a>)
    end
    _btn.html_safe
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
    else
      _btn << %(<form id="nativeapp-form" action="#{install_url}" method="post"> </form>)
      _btn << %(<a class="btn btn-default btn-primary install-app #{install_btn_class}"> #{install_btn_text} </a>)
    end
    _btn
  end

  def configs_url_params(extension, install_status)
    {}.tap do |url_params| 
      url_params[:type] = params[:type]
      url_params[:category_id] = params[:category_id] if params[:category_id]
      url_params[:installation_type] = install_status['installed'] ? 'upgrade' : 'install'
      url_params[:display_name] = extension['display_name']
    end.to_query
  end

  def category_url(category)
    category_params = { 
                        :type => params[:type],
                        :category_id => category['id']
                      }
    admin_marketplace_extensions_path + '?' + category_params.to_query
  end

  def category_name(categories)
    params[:category_id] ? categories.find {|x| x['id'] == params[:category_id].to_i}['name'] : t('marketplace.all_categories')
  end

  def search_placeholder
    (User.current && User.current.language != I18n.default_locale.to_s) ? 
      t('marketplace.search_language_warning') : t('marketplace.search')
  end
end