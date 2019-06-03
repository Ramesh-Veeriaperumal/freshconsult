require 'rack/throttle'

class Middleware::FdApiThrottler < Rack::Throttle::Hourly
  include Redis::RedisKeys
  include Redis::RateLimitRedis

  FRESHDESK_DOMAIN = 'freshdesk'
  SKIPPED_SUBDOMAINS =  %w(admin billing signup freshsignup email login emailparser mailboxparser freshops) + FreshopsSubdomains + PartnerSubdomains 
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
    @shard        = fetch_shard(env)

    if @shard.try(:not_found?)
      Rails.logger.debug "Domain Not Found while throttling :: Host: #{@host}"
      @status, @headers, @response = NOT_FOUND_RESPONSE
    elsif throttle?
      @api_limit = api_limit
      increment_redis_key(DEFAULT_USED_LIMIT)
      expiry_set = set_redis_expiry(key, THROTTLE_PERIOD) if @count <= used_limit # Setting expiry for first time.

      if allowed?
        @status, @headers, @response = @app.call(@request.env)
        # In order to avoid a 'get' and an 'incrby' call to redis for every request, 'incrby' is being called twice conditionally.
        unless extra_credits == 0
          increment_redis_key(extra_credits)
          # Expiry should be set immediately after increment, as the expiry condition depends on the incremented value.
          # expiry_set will be true when it is already set in the current request.
          # if expiry happens during @app.call, @count will be less than used_limit. Hence checking '<=' instead of '=='
          set_redis_expiry(key, THROTTLE_PERIOD) if !expiry_set && (@count <= used_limit)
        end
        set_rate_limit_headers if @count
        Rails.logger.debug("Throttled :: Host: #{@host}, Time: #{Time.now}, Count: (#{@count}), AccountId: #{ Account.current.nil? ? "nil" :  Account.current.id }")
      else
        retry_value = handle_expiry_not_set
        @status, @headers, @response = [429, { 'Retry-After' => retry_value.to_s, 'Content-Type' => 'application/json' },
                                        LIMIT_EXCEEDED_MESSAGE]
        Rails.logger.error("429 Error :: Host: #{@host}, Time: #{Time.now}, Count: #{@count}}")
      end
    else
      @status, @headers, @response = @app.call(@request.env)
    end

    set_version_headers unless @status == 404 # Version will not be present if status is 404
    [@status, @headers, @response]
  ensure
    unset_current_account
    unset_shard_in_env(env)
  end

  private

    def handle_expiry_not_set
      retry_value = retry_after.to_i
      if retry_value < 0
        Rails.logger.error("Expiry not set properly :: Host: #{@host}, Retry Value: #{retry_value}, Time: #{Time.now}, Count: #{@count}}")
        retry_value = 1
        set_redis_expiry(key, retry_value)
      end
      retry_value
    end

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
      return false if throttled_in_fluffy?
      Rails.logger.info "Inside throttle? method :: Host: #{@host}, SOURCE IP: #{@request.env['HTTP_X_REAL_IP']}"
      !skipped_domain? && account_id
    end

    def increment_redis_key(used)
      @count = increment_redis(key, used.to_i).to_i
    end

    def allowed?
      @shard.try(:ok?) ? @count <= @api_limit : true
    end

    def retry_after
      handle_exception { return $rate_limit.perform_redis_op("ttl", key) }
    end

    def extra_credits
      CustomRequestStore.store[:extra_credits]
    end

    def set_rate_limit_headers # Rate Limit headers are not set when status is 429
      remaining = [(@api_limit - @count), 0].max.to_s
      @headers = @headers.merge('X-RateLimit-Total' => @api_limit.to_s,
                                'X-RateLimit-Remaining' => remaining,
                                'X-RateLimit-Used-CurrentRequest' => used_limit.to_s)
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
      Rails.logger.error "Exception while fetching subscription_plan_id :: Host: #{@host}, Message: #{e.message}, Time: #{Time.now}"
      NewRelic::Agent.notice_error(e, custom_params: { description: 'Freshdesk API Throttler Error',
                                                       domain: @host, account_id: account_id })
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

    # This is the first custom middleware which has account based logic where the api request will hit first.
    # So setting env & thread variable here and unsetting it in ensure block. Only CorsEnabler is present above this in the chain.
    # If any middleware is going to be at the top of the chain with account based logic, all this should move there.
    def fetch_shard(env)
      shard = ShardMapping.lookup_with_domain(env["HTTP_HOST"])
      if shard
        env['SHARD'] = shard
        # Finding account & setting it in the thread variable also here. So trusted ip & controller will make use of it.
        # Instead of finding the account repeatedly in trusted_ip & controllers.
        Sharding.run_on_shard(shard.shard_name) do
          account = Account.find_by_id(shard.account_id)
          account ? account.make_current : unset_current_account
        end
      else
        unset_shard_in_env(env)
        unset_current_account
      end
      env['SHARD']
    end

    def unset_shard_in_env(env)
      env['SHARD'] = nil
    end

    def unset_current_account
      Thread.current[:account] = nil
    end

    def throttled_in_fluffy?
      Account.current && Account.current.fluffy_enabled? && @request.env['HTTP_X_FW_RATELIMITING_MANAGED'] == "true"
    end

end
