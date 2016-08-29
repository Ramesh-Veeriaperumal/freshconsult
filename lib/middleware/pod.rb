class Middleware::Pod

  def initialize(app)
    @app = app
  end

  def call(env)

    @host = env["HTTP_HOST"]
    @fullpath = env["PATH_INFO"]
    @original_fullpath = env["ORIGINAL_FULLPATH"]

    @redirect_url = nil

    if integrations_url?(@host)
      # check and redirect

      Rails.logger.info "Request fullpath: #{@fullpath}"
      # Rails.logger.info "Request ENV: #{env.inspect}"
      determine_login(env)
    end

    if redirect?
      Rails.logger.error "Redirecting to the correct POD. Redirect URL is #{@redirect_url}"

      response = Rack::Response.new
      response.redirect(@redirect_url)
      response.headers["X-Accel-Redirect"] = @redirect_url
      response.headers["X-Accel-Buffering"] = "off"
      response.finish
    else
      @status, @headers, @response = @app.call(env)
    end
  end

  # TODOLOGIN: Need to introduce remote_id type here
  def determine_login(env)
    # check for provider
    Rails.logger.info 'determine_login'
    provider_match = %r{/(?:\bauth\b|\bintegrations\b|\badmin/ecommerce\b|\becommerce\b)/([\w]+)(?:/)?(?:callback$|home/.*|authorize|tickets)?}.match @fullpath
    
    if (provider_match and provider_match[1])
      provider = provider_match[1]
      Rails.logger.info "Provider: #{provider}"
      case provider
        when 'google_login'
          Rails.logger.info 'Determining login for google.'
          query = Rack::Utils.parse_nested_query(env['QUERY_STRING'])
          return if (query.blank? || query['state'].blank?)
          state_params = CGI.parse(URI.decode(query['state']))
          return if state_params["portal_domain"][0].blank?
          shard = ShardMapping.lookup_with_domain(state_params["portal_domain"][0])
          determine_pod(shard)
        when 'google_marketplace_sso', 'google_gadget'
          return
        when 'twitter'
          return
        when 'hootsuite'
          params = env["rack.request.query_hash"].merge(env["rack.request.form_hash"] || {})
          shard = nil
          if params.include?('freshdesk_domain')
            shard = fetch_shard(params['freshdesk_domain'])
          elsif params.include?('uid')
            shard = fetch_remote_mapping(params['uid'])
          end
          determine_pod(shard)
        when 'ebay_accounts', 'ebay_notifications'
          shard = nil
          params = env["rack.request.query_hash"].merge(env["action_dispatch.request.request_parameters"] || {})
          if params['account_url']
            shard = fetch_shard(params['account_url'])
          elsif params.include?('uid')
            shard = fetch_remote_mapping(params['uid'])
          elsif params['Envelope'] && params['Envelope']['Body']
            shard = fetch_remote_mapping(params['Envelope']['Body']["#{params['Envelope']['Body'].keys.first}"]['EIASToken'])
          end
          determine_pod(shard)
        else
          origin = env['rack.session']['omniauth.origin']
          account_id = nil

          return if origin.nil?
          origin = CGI.parse(origin)
          Rails.logger.info "origin: #{origin}"
          if origin.has_key?('id') 
            Rails.logger.info "in origin.has_key?('id')"
            account_id = origin['id'][0].to_i
          end

          shard = ShardMapping.fetch_by_account_id(account_id)
          determine_pod(shard) if shard
      end
    end
  end

  def determine_pod(shard)
    Rails.logger.info "Shard #{shard.inspect}"
    if shard && PodConfig['CURRENT_POD'] != shard.pod_info
      Rails.logger.error "Current POD #{PodConfig['CURRENT_POD']}"
      @redirect_url = "/pod_redirect/#{shard.pod_info}"
    end
  end
  
  def fetch_shard(url)
    ShardMapping.lookup_with_domain(url.split("//").last)
  end

  def fetch_remote_mapping(uid)
    remote_mapping = RemoteIntegrationsMapping.find_by_remote_id(uid)
    ShardMapping.lookup_with_account_id(remote_mapping.account_id) if remote_mapping
  end

  def redirect?
    !@redirect_url.blank?
  end

  def integrations_url?(host)
    host == ::INTEGRATION_URL
  end

end