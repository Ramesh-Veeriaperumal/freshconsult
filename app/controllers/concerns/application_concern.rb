module Concerns::ApplicationConcern
  extend ActiveSupport::Concern

  private

  def append_info_to_payload(payload)
    super
    payload[:domain] = request.env['HTTP_HOST']
    payload[:ip] = request.env['CLIENT_IP']
    payload[:url] = request.url
    payload[:server_ip] = request.env['SERVER_ADDR']
    payload[:account_id] = Account.current ? Account.current.id : ""
    payload[:user_id]    = (Account.current && User.current) ? User.current.id : ""
    payload[:shard_name] = Thread.current[:shard_name_payload]
    payload[:uuid]    = Thread.current[:message_uuid]
  end

  def set_shard_for_payload  # For log
    if Thread.current[:shard_selection]
      Thread.current[:shard_name_payload] = Thread.current[:shard_selection].shard
    end
  end

  def unset_shard_for_payload
    Thread.current[:shard_name_payload] = nil
  end

  def day_pass_expired_json
    @error = RequestError.new(:access_denied)
    render template: '/request_error', status: 403
  end

  def unset_current_account
    Thread.current[:account] = nil
  end

  def unset_current_portal
    Thread.current[:portal] = nil
  end

  def unset_current_languge
    Thread.current[:language] = nil
  end

  def set_msg_id
    Thread.current[:message_uuid] = request.try(:uuid).to_a
  end

  def unset_thread_variables
    Va::Logger::Automation.unset_thread_variables
    Thread.current[:app_integration] = nil
  end

  # See http://stackoverflow.com/questions/8268778/rails-2-3-9-encoding-of-query-parameters
  # See https://rails.lighthouseapp.com/projects/8994/tickets/4807
  # See http://jasoncodes.com/posts/ruby19-rails2-encodings (thanks for the following code, Jason!)
  def force_utf8_params
    traverse = lambda do |object, block|
      if object.is_a?(Hash)
        object.each_value { |o| traverse.call(o, block) }
      elsif object.is_a?(Array)
        object.each { |o| traverse.call(o, block) }
      else
        block.call(object)
      end
      object
    end
    force_encoding = lambda do |o|
      RubyBridge.force_utf8_encoding(o)
    end
    traverse.call(params, force_encoding)
  end

  def determine_pod
    shard = fetch_shard
    return if shard.nil? or shard.pod_info.blank?
    if shard.pod_info != PodConfig['CURRENT_POD']
      Rails.logger.error "Current POD #{PodConfig['CURRENT_POD']}"
      redirect_to_pod(shard)
    end
  end

  def redirect_to_pod(shard)
    Rails.logger.error "Request URL: #{request.url}"
    # redirect to the correct POD using Nginx specific redirect headers.
    # redirect_url should match with the location directive in Nginx Proxy
    redirect_url = Redis::RoutesRedis.pod_redirection_enabled? ? "@pod_redirect_#{shard.pod_info}" : "/pod_redirect/#{shard.pod_info}"
    Rails.logger.error "Redirecting to the correct POD. Redirect URL is #{redirect_url}"
    response.headers['X-Accel-Redirect'] = redirect_url
    response.headers['X-Accel-Buffering'] = 'off'
    redirect_to redirect_url
  end

  def select_shard(&_block)
    shard = fetch_shard

    if shard.nil?
      raise ShardNotFound
    elsif shard.blocked?
      raise AccountBlocked
    elsif !shard.ok?
      raise DomainNotReady
    else
      Sharding.run_on_shard(shard.shard_name) do
        yield
      end
    end
  end

  def fetch_shard
    env['SHARD'] ||= ShardMapping.lookup_with_domain(request_host)
  end

  def set_account_meta_cookies
    set_httponly_cookie(HashedData['shard_name'], HashedData[env['SHARD'].shard_name]) if env['SHARD']
    set_httponly_cookie(HashedData['state'], HashedData[Account.current.subscription.state]) if Account.current
  end

  def set_httponly_cookie(cookie_name, cookie_val)
    cookies[cookie_name] = { value: cookie_val, httponly: true }
  end

  def can_supress_logs?
    return false unless Rails.env.production?

    LoggerConstants::SKIP_LOGS_FOR.key?(nscname.to_sym) &&
      LoggerConstants::SKIP_LOGS_FOR[nscname.to_sym].include?(action_name)
  end
end
