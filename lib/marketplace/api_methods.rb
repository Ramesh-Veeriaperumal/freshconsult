module Marketplace::ApiMethods
  include Marketplace::Constants
  include Marketplace::ApiUtil

  FRESH_REQUEST_EXP = [ FreshRequest::NetworkError, FreshRequest::CBError, FreshRequest::ParseError ]

  private

    def oauth_handshake(is_reauthorize = false, extension_id = params[:extension_id], version_id = params[:version_id],
     oauth_iparams = params[:oauth_iparams], installed_extn_id = params[:installed_extn_id])
      callback = Marketplace::ApiEndpoint::ENDPOINT_URL[:oauth_callback] % {
        :extension_id => extension_id,
        :version_id => version_id
      }
      oauth_callback_url =  "#{request.protocol}#{request.host_with_port}" + callback
      mkp_oauth_endpoint = Marketplace::ApiEndpoint::ENDPOINT_URL[:oauth_install] % {
        :product_id => PRODUCT_ID.to_s,
        :account_id => Account.current.id.to_s,
        :version_id => version_id
      }
      
      redirect_url = "#{MarketplaceConfig::MKP_OAUTH_URL}/#{mkp_oauth_endpoint}"
      fdcode = CGI.escape(generate_md5_digest(redirect_url, MarketplaceConfig::API_AUTH_KEY))
      
      queryParams = {}
      queryParams[:oauth_iparams] = oauth_iparams if oauth_iparams.present? & !oauth_iparams.blank?

      if params.has_key?(:extension_id) # For Account Level OAuth alone add callback url.
        reauth_param = is_reauthorize ? "&edit_oauth=true&installed_extn_id=#{installed_extn_id}" : ""
        queryParams[:callback] = "#{oauth_callback_url}#{reauth_param}"
      end

      "#{redirect_url}?fdcode=#{fdcode}#{queryParams.blank? ? '' : '&' + queryParams.to_query}"
    end

    # Global API's
    def mkp_extensions(sort_key = nil)
      begin
        sort_params = sort_key ? sort_key : 'popular'
        category = params[:category_id] ? params[:category_id] : 'ALL'
        key = MemcacheKeys::MKP_EXTENSIONS % { 
          :category_id => category, :type => params[:type],:locale_id => curr_user_language,
          :sort_by => sort_params, :platform_version => platform_version }
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
        key = MemcacheKeys::CUSTOM_APPS % { :account_id => Account.current.id, :locale_id => curr_user_language,
              :platform_version => platform_version }

        api_payload = payload(
                           Marketplace::ApiEndpoint::ENDPOINT_URL[:mkp_custom_apps] %
                           { :product_id => PRODUCT_ID, :account_id => Account.current.id },
                           Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:mkp_custom_apps] 
                        )
        mkp_memcache_fetch(key, MarketplaceConfig::CUSTOM_APPS_CACHE_INVD_TIME) do
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

    def extension_details(extension_id = params[:extension_id], extension_type = params[:type], force = false)
      begin
        key = MemcacheKeys::EXTENSION_DETAILS % { 
          :extension_id => extension_id, :locale_id => curr_user_language, :platform_version => platform_version}
        api_payload = payload(
                            Marketplace::ApiEndpoint::ENDPOINT_URL[:extension_details]  % 
                            { 
                              :product_id => PRODUCT_ID,
                              :extension_id => extension_id 
                            },
                            Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:extension_details] 
                          )
        cache_expiry = extension_type.to_i == EXTENSION_TYPE[:custom_app] ? MarketplaceConfig::CUSTOM_APPS_CACHE_INVD_TIME 
          : MarketplaceConfig::CACHE_INVALIDATION_TIME
        mkp_memcache_fetch(key, cache_expiry, force) do
          get_api(api_payload, MarketplaceConfig::GLOBAL_API_TIMEOUT)
        end
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def extension_details_v2(extension_id, version_id)
      begin
        key = MemcacheKeys::EXTENSION_DETAILS_V2 % { 
          :extension_id => extension_id, :version_id => version_id, :locale_id => curr_user_language }
        api_payload = payload(
                            Marketplace::ApiEndpoint::ENDPOINT_URL[:extension_details]  % 
                            { 
                              :product_id => PRODUCT_ID,
                              :extension_id => extension_id
                            },
                            Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:extension_details],
                            :version_id => version_id
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

    # API to fetch version details for list of installed versions for any platform_versions
    def v2_versions(version_ids = [])
      begin
        api_payload = payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:v2_versions] %
                { :product_id => PRODUCT_ID },
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:v2_versions],
                { :version_ids => version_ids })
        get_api(api_payload, MarketplaceConfig::GLOBAL_API_TIMEOUT)
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

    def iframe_settings
      begin
        key = MemcacheKeys::IFRAME_SETTINGS % { :version_id => params[:version_id] }
        api_payload = payload(
                            Marketplace::ApiEndpoint::ENDPOINT_URL[:iframe_settings] %
                                  { :product_id => PRODUCT_ID,
                                    :version_id => params[:version_id] },
                            Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:iframe_settings] 
                          )
        mkp_memcache_fetch(key, MarketplaceConfig::CACHE_INVALIDATION_TIME) do
          get_api(api_payload, MarketplaceConfig::GLOBAL_API_TIMEOUT)
        end
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
        include_params = [SECURE_IPARAMS]
        include_params << OAUTH_IPARAMS if params[:page] == OAUTH_IPARAMS
        params[:include] = include_params.join(',')
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
        install_request_obj = post_api(api_payload, post_params, MarketplaceConfig::ACC_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      else
        mark_custom_app_setup if (install_request_obj.status == 200)
        install_request_obj
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
        api_payload = mkp_oauth_payload(Marketplace::ApiEndpoint::ENDPOINT_URL[:fetch_tokens])
          get_api(api_payload, MarketplaceConfig::MKP_OAUTH_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def fetch_app_status(installed_extension_id = params[:installed_extension_id])
      begin
        api_payload = account_payload(
          Marketplace::ApiEndpoint::ENDPOINT_URL[:app_status] %
                { :product_id => PRODUCT_ID,
                  :account_id => Account.current.id,
                  :installed_extension_id => installed_extension_id },
          Marketplace::ApiEndpoint::ENDPOINT_PARAMS[:app_status])
          get_api(api_payload, MarketplaceConfig::ACC_API_TIMEOUT)
      rescue *FRESH_REQUEST_EXP => e
        exception_logger("Exception type #{e.class},URL: #{api_payload} #{e.message}\n#{e.backtrace}")
      end
    end

    def list_api_url(account_id)
      Marketplace::ApiEndpoint::ENDPOINT_URL[:installed_extensions] % { 
        product_id: Marketplace::Constants::PRODUCT_ID,
        account_id: account_id
      }
    end

    def show_api_url(extension_id)
      Marketplace::ApiEndpoint::ENDPOINT_URL[:extension_details]  % { 
        product_id:  Marketplace::Constants::PRODUCT_ID,
        extension_id: extension_id 
      }
    end

    def fetch_installed_extensions(account_id, types)
      api_url = list_api_url(account_id)
      list_url = account_payload(api_url, {}, { type: types.join(',') })
      log_on_error get_api(list_url, MarketplaceConfig::ACC_API_TIMEOUT)
    rescue *FRESH_REQUEST_EXP => e
      exception_logger("Exception type #{e.class}, URL: #{list_url} \
        #{e.message}\n#{e.backtrace}")
    end

    def fetch_extension_details(extension_id)
      show_url = payload(show_api_url(extension_id), {})
      log_on_error get_api(show_url, MarketplaceConfig::GLOBAL_API_TIMEOUT)
    rescue *FRESH_REQUEST_EXP => e
      exception_logger("Exception type #{e.class}, URL: #{show_url} \
        #{e.message}\n#{e.backtrace}")
    end

    def log_on_error(response)
      return response.body unless error_status?(response)
      exception_logger("Error in fetching installed app caller method: \
        #{caller[0]}, error: #{response.inspect}")
    end
end
