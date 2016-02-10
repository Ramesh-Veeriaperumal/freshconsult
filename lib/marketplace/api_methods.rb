module Marketplace::ApiMethods
  include Marketplace::Constants
  include Marketplace::ApiUtil

  private

    # Global API's
    def mkp_extensions
      category = params[:category_id] ? params[:category_id] : 'ALL'
      key = MemcacheKeys::MKP_EXTENSIONS % { :category_id => category }
      MemcacheKeys.fetch(key, MarketplaceConfig::CACHE_INVALIDATION_TIME) do
        payload = payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:mkp_extensions] %
                { :product_id => PRODUCT_ID},
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:mkp_extensions] )
        { :extensions => get_api(payload) }
      end
    end

    def mkp_extensions_search
      payload = payload(
        Marketplace::ApiEndpoint::ENDPOINT_URL[:extensions_search] %
              { :product_id => PRODUCT_ID},
        Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:extensions_search] )
      get_api(payload)
    end

    def show_extension
      payload = payload(
        Marketplace::ApiEndpoint::ENDPOINT_URL[:show_extension]  % 
                { :product_id => PRODUCT_ID,
                  :version_id => params[:id] },
        Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:show_extension] )
      get_api(payload)
    end

    def all_categories
      MemcacheKeys.fetch(MemcacheKeys::EXTENSION_CATEGORIES) do
        payload = payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:all_categories] % 
                { :product_id => PRODUCT_ID },
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:all_categories] )
        { :categories => get_api(payload) }
      end
    end

    def extension_configs
      payload = payload(
        Marketplace::ApiEndpoint::ENDPOINT_URL[:extension_configs] %
              { :product_id => PRODUCT_ID,
                :version_id => params[:version_id]},
        Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:extension_configs] )
      get_api(payload)
    end

    # Account API's
    def indev_extensions
      payload = payload(
        Marketplace::ApiEndpoint::ENDPOINT_URL[:indev_extension]  % 
              { :product_id => PRODUCT_ID, 
                :account_id => current_account.id
              },
        Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:indev_extension] )
      { :extensions => get_api(payload) }
    end

    def indev_extensions_search
      payload = payload(
        Marketplace::ApiEndpoint::ENDPOINT_URL[:indev_extensions_search]  % 
              { :product_id => PRODUCT_ID, 
                :account_id => current_account.id
              },
        Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:indev_extensions_search] )
      get_api(payload)
    end

    def install_status
      payload = payload(
        Marketplace::ApiEndpoint::ENDPOINT_URL[:install_status]  % 
              { :product_id => PRODUCT_ID, 
                :account_id => current_account.id,
                :version_id => params[:id]
              },
        Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:install_status] )
      get_api(payload)
    end

    def account_configs
      payload = payload(
        Marketplace::ApiEndpoint::ENDPOINT_URL[:account_configs] %
              { :product_id => PRODUCT_ID,
                :account_id => current_account.id,
                :version_id => params[:version_id] },
        Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:account_configs] )
      get_api(payload)
    end

    def install_extension(post_params)
      payload = payload(
        Marketplace::ApiEndpoint::ENDPOINT_URL[:install_extension] %
              { :product_id => PRODUCT_ID,
                :account_id => current_account.id,
                :version_id => params[:version_id] },
        Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:install_extension] )
      post_api(payload, post_params)
    end

    def update_extension(put_params)
      payload = payload(
        Marketplace::ApiEndpoint::ENDPOINT_URL[:update_extension] %
              { :product_id => PRODUCT_ID,
                :account_id => current_account.id,
                :version_id => params[:version_id] },
        Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:update_extension] )
      put_api(payload, put_params)
    end

    def uninstall_extension
      payload = payload(
        Marketplace::ApiEndpoint::ENDPOINT_URL[:uninstall_extension] %
              { :product_id => PRODUCT_ID,
                :account_id => current_account.id,
                :version_id => params[:version_id] },
        Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:uninstall_extension] )
      delete_api(payload)
    end

    def post_feedback(post_params)
      payload = payload(
        Marketplace::ApiEndpoint::ENDPOINT_URL[:feedbacks] %
              { :product_id => PRODUCT_ID,
                :account_id => current_account.id,
                :version_id => params[:version_id] },
        Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:feedbacks] )
      post_api(payload, post_params)
    end

    def installed_extensions(optional_params = {})
      payload = payload(
        Marketplace::ApiEndpoint::ENDPOINT_URL[:installed_extensions] %
              { :product_id => PRODUCT_ID,
                :account_id => current_account.id},
        Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:installed_extensions],
        optional_params )
      get_api(payload)
    end
end