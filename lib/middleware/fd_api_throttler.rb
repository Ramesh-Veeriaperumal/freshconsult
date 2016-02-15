require 'rack/throttle'

class Middleware::FdApiThrottler < Rack::Throttle::Hourly
  include Redis::RedisKeys

  FRESHDESK_DOMAIN = 'freshdesk'
  SKIPPED_SUBDOMAINS =  %w(admin billing partner signup freshsignup email login emailparser mailboxparser freshops) + FreshopsSubdomains
  THROTTLE_PERIOD    =  1.hour
  API_LIMIT = 3000
  DEFAULT_USED_LIMIT = 1
  API_CURRENT_VERSION = 'v2'
  NOT_FOUND_RESPONSE = [404, { 'Content-Type' => 'application/json' }, [' ']]
  LIMIT_EXCEEDED_MESSAGE = [{ message: 'You have exceeded the limit of requests per hour' }.to_json]

  def initialize(app, options = {})
    super(app, options)
    @app = app
  end

  def call(env)
    @request      = Rack::Request.new(env)
    @host         = env['HTTP_HOST']
    @shard        = ShardMapping.lookup_with_domain(@host)

    if @shard.try(:not_found?)
      Rails.logger.debug "FdApiThrottler :: Domain Not Found :: #{@host}"
      @status, @headers, @response = NOT_FOUND_RESPONSE
    elsif throttle?
      @api_limit = api_limit
      increment_redis_key(DEFAULT_USED_LIMIT)

      if allowed?
        @status, @headers, @response = @app.call(@request.env)
        # In order to avoid a 'get' and an 'incrby' call to redis for every request, 'incrby' is being called twice conditionally.
        increment_redis_key(extra_credits) unless extra_credits == 0
        set_rate_limit_headers if @count
        Rails.logger.debug("FdApiThrottler :: Throttled :: Host: #{@host}, Count: (#{@count})")
      else
        @status, @headers, @response = [429, { 'Retry-After' => retry_after.to_s, 'Content-Type' => 'application/json' },
                                        LIMIT_EXCEEDED_MESSAGE]
        Rails.logger.error("API 429 Error :: Time: #{Time.now}, Host: #{@host}, Count: #{@count}}")
      end
    else
      @status, @headers, @response = @app.call(@request.env)
    end

    set_version_headers unless @status == 404 # Version will not be present if status is 404
    [@status, @headers, @response]
  end

  private

    def account_id
      @shard.try(:account_id)
    end

    def skipped_domain?
      split_host = @host.split('.')
      subdomain = split_host[0]
      domain = split_host[1]
      SKIPPED_SUBDOMAINS.include?(subdomain) && domain == FRESHDESK_DOMAIN
    end

    def throttle?
      Rails.logger.debug "SOURCE IP :: #{@request.env['HTTP_X_REAL_IP']}, DOMAIN :: #{@host}"
      !skipped_domain? && account_id
    end

    def increment_redis_key(used)
      @count = increment_redis(key, used).to_i
      set_redis_expiry(key, THROTTLE_PERIOD) if @count == used_limit # Setting expiry for first time.
    end

    def allowed?
      @shard.try(:ok?) ? @count <= @api_limit : true
    end

    def retry_after
      handle_exception { return $rate_limit.ttl(key) }
    end

    def extra_credits
      RequestStore.store[:extra_credits]
    end

    def set_rate_limit_headers # Rate Limit headers are not set when status is 429
      remaining = [(@api_limit - @count), 0].max.to_s
      @headers = @headers.merge('X-RateLimit-Total' => @api_limit.to_s, 
                                'X-RateLimit-Remaining' => remaining,
                                'X-RateLimit-Used' => used_limit.to_s)
    end

    def set_version_headers
      version = api_version
      @headers = @headers.merge('X-Freshdesk-API-Version' => "latest=#{API_CURRENT_VERSION}; requested=#{version}") if version
    end

    def account_api_limit_key
      ACCOUNT_API_LIMIT % { account_id: account_id }
    end

    def default_api_limit_key
      DEFAULT_API_LIMIT
    end

    def api_limit
      api_limits = get_multiple_redis_keys(account_api_limit_key, plan_api_limit_key, default_api_limit_key) || []
      (api_limits[0] || api_limits[1] || api_limits[2] || API_LIMIT).to_i
    end

    def plan_api_limit_key
      if plan_id = fetch_plan_id
        PLAN_API_LIMIT % { plan_id: plan_id }
      end
    end

    def fetch_plan_id
      Sharding.run_on_shard(@shard.shard_name) do
        Subscription.fetch_by_account_id(account_id).try(:plan_id)
      end
    rescue Exception => e
      Rails.logger.error "Exception on FdApiThrottler ::: #{e.message}"
      NewRelic::Agent.notice_error(e, custom_params: { description: 'Freshdesk API Throttler Error',
                                                       domain: @host, account_id: account_id })
    end

    def increment_redis(key, used)
      handle_exception { return $rate_limit.INCRBY(key, used) }
    end

    def set_redis_expiry(key, expires)
      handle_exception { $rate_limit.expire(key, expires) }
    end

    def get_multiple_redis_keys(*keys)
      handle_exception { $rate_limit.mget(*keys) }
    end

    def key
      API_THROTTLER_V2 % { account_id: account_id }
    end

    def used_limit
      DEFAULT_USED_LIMIT + extra_credits.to_i
    end

    def api_version
      @request.env['action_dispatch.request.path_parameters'].try(:[], :version) # This parameter would come from api_routes
    end

    def handle_exception
      # similar to newrelic_begin_rescue, additionally logs and sends more info to newrelic.
        yield
      rescue Exception => e
        options_hash =  { uri: @request.env['REQUEST_URI'], custom_params: @request.env["action_dispatch.request_id"], 
          description: "Error occurred while accessing Redis", request_method: @request.env['REQUEST_METHOD'], 
          request_body: @request.env["rack.input"].gets }
        Rails.logger.error("FdApiThrottler :: Redis Exception, Host: #{@host}, Exception: #{e.message}\n#{e.class}\n#{e.backtrace.join("\n")}")
        NewRelic::Agent.notice_error(e, options_hash)
        return
    end
end
