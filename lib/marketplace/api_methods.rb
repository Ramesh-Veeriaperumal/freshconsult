module Marketplace::ApiMethods
  include Marketplace::Constants
  include Marketplace::ApiUtil

  FRESH_REQUEST_EXP = [ FreshRequest::NetworkError, FreshRequest::CBError, FreshRequest::ParseError ]

  private

    # Global API's
    def mkp_extensions(sort_key = nil)
      begin
        sort_params = sort_key ? sort_key : 'popular'
        category = params[:category_id] ? params[:category_id] : 'ALL'
        key = MemcacheKeys::MKP_EXTENSIONS % { 
          :category_id => category, :type => params[:type],:locale_id => curr_user_language,
          :sort_by => sort_params }
        api_payload = payload(
                           Marketplace::ApiEndpoint::ENDPOINT_URL[:mkp_extensions] %
                           { :product_id => PRODUCT_ID },
                           Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:mkp_extensions],
                           {:sort_by => sort_key } 
                        )
        mkp_memcache_fetch(key, MarketplaceConfig::CACHE_INVALIDATION_TIME) do
          get_api(api_payload, MarketplaceConfig::GLOBAL_API_TIMEOUT) 
        end

      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def mkp_custom_apps
      begin
        key = MemcacheKeys::CUSTOM_APPS % { :account_id => Account.current.id, :locale_id => curr_user_language }

        api_payload = payload(
                           Marketplace::ApiEndpoint::ENDPOINT_URL[:mkp_custom_apps] %
                           { :product_id => PRODUCT_ID, :account_id => Account.current.id },
                           Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:mkp_custom_apps] 
                        )
        mkp_memcache_fetch(key, MarketplaceConfig::CACHE_INVALIDATION_TIME) do
          get_api(api_payload, MarketplaceConfig::GLOBAL_API_TIMEOUT) 
        end

      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def search_mkp_extensions
      begin
        api_payload = payload(
                           Marketplace::ApiEndpoint::ENDPOINT_URL[:search_mkp_extensions] %
                           { :product_id => PRODUCT_ID },
                           Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:search_mkp_extensions]
                        )
        get_api(api_payload, MarketplaceConfig::GLOBAL_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def auto_suggest_mkp_extensions
      begin
        api_payload = payload(
                           Marketplace::ApiEndpoint::ENDPOINT_URL[:auto_suggest_mkp_extensions] %
                           { :product_id => PRODUCT_ID },
                           Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:auto_suggest_mkp_extensions]
                        )

        get_api(api_payload, MarketplaceConfig::GLOBAL_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def extension_details(extension_id = params[:extension_id])
      begin
        key = MemcacheKeys::EXTENSION_DETAILS % { 
          :extension_id => extension_id, :locale_id => curr_user_language }
        api_payload = payload(
                            Marketplace::ApiEndpoint::ENDPOINT_URL[:extension_details]  % 
                            { 
                              :product_id => PRODUCT_ID,
                              :extension_id => extension_id 
                            },
                            Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:extension_details] 
                          )
        mkp_memcache_fetch(key, MarketplaceConfig::CACHE_INVALIDATION_TIME) do
          get_api(api_payload, MarketplaceConfig::GLOBAL_API_TIMEOUT)
        end
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def version_details(version_id = params[:version_id])
      begin
        key = MemcacheKeys::VERSION_DETAILS % { :version_id => version_id }
        api_payload = payload(
                            Marketplace::ApiEndpoint::ENDPOINT_URL[:version_details]  % 
                            { 
                              :product_id => PRODUCT_ID,
                              :version_id => version_id 
                            },
                            Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:version_details] 
                          )
        mkp_memcache_fetch(key, MarketplaceConfig::CACHE_INVALIDATION_TIME) do
          get_api(api_payload, MarketplaceConfig::GLOBAL_API_TIMEOUT)
        end
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def all_categories
      begin
        api_payload = payload(
                            Marketplace::ApiEndpoint::ENDPOINT_URL[:all_categories] % 
                            { :product_id => PRODUCT_ID },
                            Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:all_categories] 
                          )
        mkp_memcache_fetch(MemcacheKeys::EXTENSION_CATEGORIES) do
          get_api(api_payload, MarketplaceConfig::GLOBAL_API_TIMEOUT) 
        end
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def extension_configs
      begin
        key = MemcacheKeys::CONFIGURATION_DETAILS % { 
          :version_id => params[:version_id], :locale_id => curr_user_language }
        api_payload = payload(
                          Marketplace::ApiEndpoint::ENDPOINT_URL[:extension_configs] %
                                { :product_id => PRODUCT_ID,
                                  :version_id => params[:version_id]},
                          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:extension_configs] 
                          )
        @extension_configs ||= mkp_memcache_fetch(key, MarketplaceConfig::CACHE_INVALIDATION_TIME) do
          get_api(api_payload, MarketplaceConfig::GLOBAL_API_TIMEOUT)
        end
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def ni_latest_details(name)
      begin
        api_payload = payload(
                            Marketplace::ApiEndpoint::ENDPOINT_URL[:ni_latest_details] %
                                  { :product_id => PRODUCT_ID,
                                    :app_name => name },
                            Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:ni_latest_details] 
                          )
        get_api(api_payload, MarketplaceConfig::GLOBAL_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    # Account API's
    def install_status
      begin
        extn_details = extension_details
        return extn_details if error_status?(extn_details)

        api_payload = account_payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:install_status]  % 
                { :product_id => PRODUCT_ID, 
                  :account_id => Account.current.id,
                  :extension_id => extn_details.body['extension_id']
                },
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:install_status] )
        get_api(api_payload, MarketplaceConfig::ACC_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def account_configs
      begin
        api_payload = account_payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:account_configs] %
                { :product_id => PRODUCT_ID,
                  :account_id => Account.current.id,
                  :version_id => params[:version_id] },
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:account_configs] )
         @account_configs ||= get_api(api_payload, MarketplaceConfig::ACC_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def install_extension(post_params)
      begin
        api_payload = account_payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:install_extension] %
                { :product_id => PRODUCT_ID,
                  :account_id => Account.current.id,
                  :extension_id => post_params[:extension_id]},
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:install_extension] )
        post_api(api_payload, post_params, MarketplaceConfig::ACC_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def update_extension(put_params)
      begin
        api_payload = account_payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:update_extension] %
                { :product_id => PRODUCT_ID,
                  :account_id => Account.current.id,
                  :extension_id => put_params[:extension_id] },
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:update_extension] )
        put_api(api_payload, put_params, MarketplaceConfig::ACC_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def uninstall_extension(delete_params)
      begin
        api_payload = account_payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:uninstall_extension] %
                { :product_id => PRODUCT_ID,
                  :account_id => Account.current.id,
                  :extension_id => delete_params[:extension_id]},
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:uninstall_extension] )
        delete_api(api_payload, delete_params, MarketplaceConfig::ACC_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def installed_extensions(optional_params = {})
      begin
        api_payload = account_payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:installed_extensions] %
                { :product_id => PRODUCT_ID,
                  :account_id => Account.current.id},
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:installed_extensions],
          optional_params )
        get_api(api_payload, MarketplaceConfig::ACC_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def installed_extension_details(extension_id = params[:extension_id])
      begin
        api_payload = account_payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:installed_extension_details] %
                { :product_id => PRODUCT_ID,
                  :account_id => Account.current.id,
                  :extension_id => extension_id },
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:installed_extension_details] )
        get_api(api_payload, MarketplaceConfig::ACC_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def fetch_tokens
      begin
        api_payload = mkp_oauth_payload(
                        Marketplace::ApiEndpoint::ENDPOINT_URL[:fetch_tokens],
                        Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:fetch_tokens]
                      )
          get_api(api_payload, MarketplaceConfig::MKP_OAUTH_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end
end