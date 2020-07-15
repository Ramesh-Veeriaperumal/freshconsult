class Middleware::PodRedirect

  def initialize(app)
    @app = app
  end

  def call(env)
    env['SHARD'] ||= ShardMapping.lookup_with_domain(env['HTTP_HOST'])
    if env['SHARD'] && env['SHARD'].pod_info != PodConfig['CURRENT_POD']
      Rails.logger.info "Redirecting to the correct POD -> #{env['SHARD'].pod_info}"
      response = Rack::Response.new
      # Nginx version >= 1.10.x will not preserve the original request method for the internal
      # redirect to a location. It will preserve the orginal request method only for the internal named location
      # Please see https://forum.nginx.org/read.php?2,263661,264440#msg-264440
      response.headers['X-Accel-Redirect'] = "@pod_redirect_#{env['SHARD'].pod_info}"
      response.headers['X-Accel-Buffering'] = 'off'
      response.finish
    else
      if env['HTTP_X_REAL_IP'].present? && env['HTTP_X_SECRET_TOKEN_FD_POD_REDIRECT'].present?
        env['HTTP_X_FORWARDED_FOR'] = env['HTTP_X_REAL_IP']
        env['REMOTE_ADDR'] = env['HTTP_X_REAL_IP']
        env['CLIENT_IP'] = env['HTTP_X_REAL_IP']
      end
      @status, @headers, @response = @app.call(env)
    end
  end
end
