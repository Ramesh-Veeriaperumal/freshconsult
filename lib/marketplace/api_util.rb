module Marketplace::ApiUtil

  private

    def payload(part_of_url, url_params, optional_params = {})
      payload_params = payload_params(url_params, optional_params)
      "#{MarketplaceConfig::API_URL}/#{part_of_url}#{payload_params}"
    end

    def payload_params(url_params, optional_params)
      params_hash = url_params.blank? ? optional_params : 
        url_params.map { |key| [key, params[key]] }.to_h.merge(optional_params)
      params_hash.reject!{ |k,v| v.nil? }
      params_hash.blank? ? '' : "?#{params_hash.to_query}"
    end

    def generate_md5_digest(url)
      digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('MD5'),
                              MarketplaceConfig::API_AUTH_KEY,
                              url)
      "Freshdesk #{digest}"
    end

    def marketplace_api(method, url, body)
       HTTParty.send(method, url,
        {
          :body => body.to_json,
          :headers => {
            'Content-Type' => 'application/json',
            'Accept' => 'application/json',
            'Authorization' => generate_md5_digest(url)
          },
          :timeout => MarketplaceConfig::API_TIMEOUT
        })
    end

    def get_api(url)
      JSON.parse(marketplace_api(:get, url, {}).body)
    end

    def post_api(url, params = {})
      @post_api ||= marketplace_api(:post, url, params)
    end

    def put_api(url, params = {})
      @put_api ||= marketplace_api(:put, url, params)
    end

    def delete_api(url)
      @delete_api ||= marketplace_api(:delete, url, {})
    end

    def data_from_url_params
      params.select do |key, _| 
        Marketplace::Constants::API_PERMIT_PARAMS.include? key.to_sym
      end
    end

    def mkp_connection_failure(exception)
      NewRelic::Agent.notice_error(exception)
      render :json => { error: exception }, status: 503
    end
end