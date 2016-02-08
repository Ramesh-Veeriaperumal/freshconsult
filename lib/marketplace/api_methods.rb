module Marketplace::ApiMethods
  include Marketplace::Constants
  include Marketplace::ApiUtil

  FRESH_REQUEST_EXP = [ FreshRequest::NetworkError, FreshRequest::CBError, FreshRequest::ParseError ]

  private

    # Global API's
    def mkp_extensions
      begin
        category = params[:category_id] ? params[:category_id] : 'ALL'
        key = MemcacheKeys::MKP_EXTENSIONS % { 
          :category_id => category, :type => params[:type], :locale_id => curr_user_language }

        payload = payload(
                           Marketplace::ApiEndpoint::ENDPOINT_URL[:mkp_extensions] %
                           { :product_id => PRODUCT_ID },
                           Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:mkp_extensions] 
                        )

        MemcacheKeys.fetch(key, MarketplaceConfig::CACHE_INVALIDATION_TIME) do
          get_api(payload, MarketplaceConfig::GLOBAL_API_TIMEOUT) 
        end

      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def extension_details(version_id = params[:version_id])
      begin
        key = MemcacheKeys::EXTENSION_VERSION_DETAILS % { 
          :version_id => version_id, :locale_id => curr_user_language }
        payload = payload(
                            Marketplace::ApiEndpoint::ENDPOINT_URL[:extension_details]  % 
                            { 
                              :product_id => PRODUCT_ID,
                              :version_id => version_id 
                            },
                            Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:extension_details] 
                          )

        @extension = MemcacheKeys.fetch(key, MarketplaceConfig::CACHE_INVALIDATION_TIME) do
          get_api(payload, MarketplaceConfig::GLOBAL_API_TIMEOUT)
        end
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def all_categories
      begin
        payload = payload(
                            Marketplace::ApiEndpoint::ENDPOINT_URL[:all_categories] % 
                            { :product_id => PRODUCT_ID },
                            Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:all_categories] 
                          )
        MemcacheKeys.fetch(MemcacheKeys::EXTENSION_CATEGORIES) do
          get_api(payload, MarketplaceConfig::GLOBAL_API_TIMEOUT) 
        end
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def extension_configs
      begin
        key = MemcacheKeys::CONFIGURATION_DETAILS % { 
          :version_id => params[:version_id], :locale_id => curr_user_language }
        payload = payload(
                          Marketplace::ApiEndpoint::ENDPOINT_URL[:extension_configs] %
                                { :product_id => PRODUCT_ID,
                                  :version_id => params[:version_id]},
                          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:extension_configs] 
                          )
        @extension_configs ||= MemcacheKeys.fetch(key, MarketplaceConfig::CACHE_INVALIDATION_TIME) do
          get_api(payload, MarketplaceConfig::GLOBAL_API_TIMEOUT)
        end
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def ni_latest_details(name)
      begin
        payload = payload(
                            Marketplace::ApiEndpoint::ENDPOINT_URL[:ni_latest_details] %
                                  { :product_id => PRODUCT_ID,
                                    :app_name => name },
                            Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:ni_latest_details] 
                          )
        get_api(payload, MarketplaceConfig::GLOBAL_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{payload} #{e.message}\n#{e.backtrace}")
      end
    end

    # Account API's
    def install_status
      begin
        extn_details = extension_details
        return extn_details if error_status?(extn_details)

        payload = account_payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:install_status]  % 
                { :product_id => PRODUCT_ID, 
                  :account_id => Account.current.id,
                  :extension_id => extn_details.body['extension_id']
                },
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:install_status] )
        get_api(payload, MarketplaceConfig::ACC_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def account_configs
      begin
        payload = account_payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:account_configs] %
                { :product_id => PRODUCT_ID,
                  :account_id => Account.current.id,
                  :version_id => params[:version_id] },
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:account_configs] )
         @account_configs ||= get_api(payload, MarketplaceConfig::ACC_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def install_extension(post_params)
      begin
        payload = account_payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:install_extension] %
                { :product_id => PRODUCT_ID,
                  :account_id => Account.current.id,
                  :extension_id => post_params[:extension_id],
                  :version_id => post_params[:version_id] },
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:install_extension] )
        post_api(payload, post_params, MarketplaceConfig::ACC_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def update_extension(put_params)
      begin
        payload = account_payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:update_extension] %
                { :product_id => PRODUCT_ID,
                  :account_id => Account.current.id,
                  :extension_id => put_params[:extension_id],
                  :version_id => put_params[:version_id] },
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:update_extension] )
        put_api(payload, put_params, MarketplaceConfig::ACC_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def uninstall_extension(delete_params)
      begin
        payload = account_payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:uninstall_extension] %
                { :product_id => PRODUCT_ID,
                  :account_id => Account.current.id,
                  :extension_id => delete_params[:extension_id],
                  :version_id => delete_params[:version_id] },
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:uninstall_extension] )
        delete_api(payload, MarketplaceConfig::ACC_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def installed_extensions(optional_params = {})
      begin
        payload = account_payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:installed_extensions] %
                { :product_id => PRODUCT_ID,
                  :account_id => Account.current.id},
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:installed_extensions],
          optional_params )
        get_api(payload, MarketplaceConfig::ACC_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{payload} #{e.message}\n#{e.backtrace}")
      end
    end
end