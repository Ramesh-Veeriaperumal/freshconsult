module Concerns::ApplicationConcern
  extend ActiveSupport::Concern

  private

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

  def set_time_zone
    TimeZone.set_time_zone
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
    shard = ShardMapping.lookup_with_domain(request.host)
    if shard.nil?
      return # fallback to the current pod.
    elsif shard.pod_info.blank?
      return # fallback to the current pod.
    elsif shard.pod_info != PodConfig['CURRENT_POD']
      Rails.logger.error "Current POD #{PodConfig['CURRENT_POD']}"
      redirect_to_pod(shard)
    end
  end

  def redirect_to_pod(shard)
    return if shard.nil?

    Rails.logger.error "Request URL: #{request.url}"
    # redirect to the correct POD using Nginx specific redirect headers.
    redirect_url = "/pod_redirect/#{shard.pod_info}" # Should match with the location directive in Nginx Proxy
    Rails.logger.error "Redirecting to the correct POD. Redirect URL is #{redirect_url}"
    response.headers['X-Accel-Redirect'] = redirect_url
    response.headers['X-Accel-Buffering'] = 'off'

    redirect_to redirect_url
 end

  def set_current_account
    current_account.make_current
    User.current = current_user
  rescue ActiveRecord::RecordNotFound
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    handle_unverified_request
  end

  def select_shard(&_block)
    Sharding.select_shard_of(request.host) do
      yield
    end
  end

end
