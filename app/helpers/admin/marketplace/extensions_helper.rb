module Admin::Marketplace::ExtensionsHelper

  include Admin::Marketplace::MarketplaceInstallHelper
  include Admin::Marketplace::CommonHelper
  include SubscriptionsHelper
  include Marketplace::HelperMethods
  include Marketplace::ApiUtil

  def install_btn(extension, install_status, is_oauth_app)
    @extension = extension
    @install_status = install_status
    @is_oauth_app = is_oauth_app
    if paid_app? && installed? && !plug_installed_in_platform? # Same Paid App can't be installed in both UI
      install_not_allowed
    elsif app_available_in_platform?
      paid_app? && !installed? ? generate_buy_app_btn : generate_install_btn
    else
      platform_not_compatible
    end
  end

  def configs_url_params(is_oauth_app = false)
    {}.tap do |url_params|
      url_params[:type] = params[:type]
      url_params[:category_id] = params[:category_id] if params[:category_id]
      url_params[:installation_type] = installed? && plug_installed_in_platform? ? 'upgrade' : 'install'
      url_params[:display_name] = @extension['display_name']
      url_params[:installed_version] = installed_version.first if installed? && plug_installed_in_platform? && !latest_installed?
      url_params[:is_oauth_app] = is_oauth_app if is_oauth_app
    end.to_query
  end

  def category_url(category)
    category_params = { 
                        :type => params[:type],
                        :category_id => category['id']
                      }
    "#{admin_marketplace_extensions_path}?#{category_params.to_query}"
  end

  def category_name(categories)
    params[:category_id] ? categories.find {|x| x['id'] == params[:category_id].to_i}['name'] : t('marketplace.all_apps')
  end

  def search_placeholder
    (User.current && User.current.language != I18n.default_locale.to_s) ? 
      t('marketplace.search_language_warning') : t('marketplace.search')
  end

  def third_party_developer?
    !is_external_app? && @extension['account'].downcase != Marketplace::Constants::DEVELOPED_BY_FRESHDESK
  end

  def app_gallery_params
    {}.tap do |app_gallery_params| 
      app_gallery_params[:type] = params[:type]
      app_gallery_params[:sort_by] = Marketplace::Constants::EXTENSION_SORT_TYPES
    end.to_query                                      
  end

  def pricing_state(extension)
    extension['pricing'] == "true" ? true : false
  end
end
