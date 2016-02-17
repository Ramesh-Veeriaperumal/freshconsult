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
    provider_match = %r{/auth/([\w]+)/callback$}.match @fullpath
    if (provider_match and provider_match[1])
      provider = provider_match[1]
      Rails.logger.info "Provider: #{provider}"
      case provider
        when 'google_login', 'google_gadget_login'
          Rails.logger.info 'Determining login for google.'
          host_url, portal_url = CGI.unescape(env["QUERY_STRING"]).scan(/full_domain=(.+)&portal_url=(.+)&.*/).flatten

          shard = ShardMapping.lookup_with_domain(host_url)
          determine_pod(shard)
        when 'twitter'
          return # For twitter redirection is based on customer portal rather than integrations url.
        else
          origin = env['rack.session']['omniauth.origin']
          account_id = nil

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
    if PodConfig['CURRENT_POD'] != shard.pod_info
      Rails.logger.error "Current POD #{PodConfig['CURRENT_POD']}"
      # redirect_to_pod(shard) and return
      @redirect_url = "/pod_redirect/#{shard.pod_info}" #Should match with the location directive in Nginx Proxy
    end
  end

  def redirect?
    !@redirect_url.blank?
  end

  def integrations_url?(host)
    Rails.logger.info "checking integrations_url for #{host}. Provided value is #{AppConfig['integrations_url'][Rails.env]}"
    host == AppConfig['integrations_url'][Rails.env].gsub(/https?:\/\//i, '') or
     (Rails.env.development? and
      host == AppConfig['integrations_url'][Rails.env].gsub(/https?:\/\//i, '').gsub(/:3000/i,''))
  end

end