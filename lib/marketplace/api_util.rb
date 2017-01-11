module Marketplace::ApiUtil

  def curr_user_language
    if User.current
      User.current.language
    elsif Portal.current
      Portal.current.language
    elsif Account.current
      Account.current.language
    else
      I18n.default_locale.to_s
    end
  end

  def generate_md5_digest(url, key)
    digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('MD5'), key, url)
    "Freshdesk #{digest}"
  end

  private

    def payload(api_endpoint, url_params, optional_params = {})
      payload_params = payload_params(url_params, optional_params)
      "#{MarketplaceConfig::API_URL}/#{api_endpoint}#{payload_params}"
    end

    def mkp_oauth_payload(api_endpoint, url_params, optional_params = {})
      payload_params = payload_params(url_params, optional_params)
      "#{MarketplaceConfig::MKP_OAUTH_URL}/#{api_endpoint}#{payload_params}"
    end

    def account_payload(api_endpoint, url_params, optional_params = {})
      payload_params = payload_params(url_params, optional_params)
      "#{MarketplaceConfig::ACC_API_URL}/#{api_endpoint}#{payload_params}"
    end

    def payload_params(url_params, optional_params)
      params_hash = url_params.blank? ? optional_params : 
        url_params.map { |key| [key, params[key]] }.to_h.merge(optional_params)
      params_hash.reject!{ |k,v| v.nil? }
      params_hash.blank? ? '' : "?#{params_hash.to_query}"
    end

    def construct_api_request(url, body, timeout)

      FreshRequest::Client.new(
                                api_endpoint: url,
                                payload: body,
                                circuit_breaker: MarketplaceConfig::MKP_CB,
                                headers: {
                                            'Content-Type' => 'application/json',
                                            'Accept' => 'application/json; 1.0.0',
                                            'Accept-Language' => curr_user_language,
                                            'Authorization' => generate_md5_digest(url, MarketplaceConfig::API_AUTH_KEY)
                                         },
                                conn_timeout: timeout[:conn],
                                read_timeout: timeout[:read]
                              )
    end

    def get_api(url, timeout)
      construct_api_request(url, {}, timeout).get
    end

    def post_api(url, params = {}, timeout)  
      post_api = construct_api_request(url, params, timeout).post
      clear_installed_cache
      post_api
    end

    def put_api(url, params = {}, timeout)
      put_api = construct_api_request(url, params, timeout).put
      clear_installed_cache
      put_api
    end

    def patch_api(url, params = {}, timeout)
      patch_api = construct_api_request(url, params, timeout).patch
      clear_installed_cache
      patch_api
    end

    def delete_api(url, params = {}, timeout)
      delete_api = construct_api_request(url, params, timeout).delete
      clear_installed_cache
      delete_api
    end
  
    def data_from_url_params
      params.select do |key, _| 
        Marketplace::Constants::API_PERMIT_PARAMS.include? key.to_sym
      end
    end

    def mkp_exception(exception)
      Rails.logger.debug "Marketplace exception : \n#{exception.message}\n#{exception.backtrace.join("\n")}"
      NewRelic::Agent.notice_error("Marketplace exception : #{exception}")
      render_error_response
    end

    def render_error_response
     render :nothing => true, :status => 503
    end

    def error_status?(data)
      data.nil? || data.status.between?(400,599)
    end

    def exception_logger(message)
      Rails.logger.error(message)
      NewRelic::Agent.notice_error(message)
    end

    def clear_installed_cache
      Marketplace::Constants::DISPLAY_PAGE.each do |page, id|
        page_key = MemcacheKeys::INSTALLED_FRESHPLUGS % { 
          :page => id, 
          :account_id => Account.current.id
        }
        MemcacheKeys.delete_from_cache page_key
      end
    end

    # Memcache for API calls - Checks for API Response Status and Cache only Successful Requests
    def mkp_memcache_fetch(key, expiry=0, &block)
      cache_data = MemcacheKeys.get_from_cache(key)
      if cache_data.nil?
        api_response = block.call
        MemcacheKeys.cache(key, cache_data = api_response, expiry) if api_response && [200,201].include?(api_response.status)
      end
      cache_data
    end
end