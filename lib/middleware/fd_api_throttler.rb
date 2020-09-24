require 'rack/throttle'

class Middleware::FdApiThrottler < Rack::Throttle::Hourly
  include Redis::RedisKeys
  include Redis::RateLimitRedis

  FRESHDESK_DOMAIN = 'freshdesk'.freeze
  SKIPPED_SUBDOMAINS =  %w[admin billing signup freshsignup email login emailparser mailboxparser freshops mars-us mars-euc mars-au mars-ind] + FreshopsSubdomains + PartnerSubdomains + CRON_HOOK_SUBDOMAIN.to_a
  THROTTLE_PERIOD    =  1.hour
  API_LIMIT = 3000
  DEFAULT_USED_LIMIT = 1
  API_CURRENT_VERSION = 'v2'.freeze
  NOT_FOUND_RESPONSE = [404, { 'Content-Type' => 'application/json' }, [' ']].freeze
  LIMIT_EXCEEDED_MESSAGE = [{ message: 'You have exceeded the limit of requests per hour' }.to_json].freeze
  HTTP_X_FW_RATELIMITING_MANAGED = 'HTTP_X_FW_RATELIMITING_MANAGED'.freeze
  HTTP_X_FWI_CLIENT_ID = 'HTTP_X_FWI_CLIENT_ID'.freeze
  API_THROTTLING_MANAGED = 'HTTP_OVERRIDE_THROTTLING'.freeze
  TRUE_STRING = 'true'.freeze

  def initialize(app, options = {})
    super(app, options)
    @app = app
  end

  # Should resolve to true for public APIs
  def correct_namespace?(_path_info)
    CustomRequestStore.read(:api_v2_request) ||
      CustomRequestStore.read(:pipe_api_request)
  end

  def call(env)
    @request = Rack::Request.new(env)

    unless correct_namespace?(@request.env['PATH_INFO'])
      call_next
      return [@status, @headers, @response]
    end

    @host         = env['HTTP_HOST']
    @shard        = fetch_shard(env)

    if shard_not_found?
      Rails.logger.debug "Domain Not Found while throttling :: Host: #{@host}"
      @status, @headers, @response = NOT_FOUND_RESPONSE
    # Skips throttling when the header API_THROTTLING_MANAGED is present, which might
    #   be set by Fluffy or HAProxy. User set headers has to be unset. Evaded the feature checks as well
    #   Shard and account info will still be fetched for domain validation, and memoized for rest of the request
    elsif skip_on_header
      Rails.logger.debug 'Skipping on header'
      call_next
    elsif throttle?
      throttle_and_proceed
    else
      call_next
    end
    set_version_headers unless @status == 404 # Version will not be present if status is 404
    [@status, @headers, @response]
  ensure
    @api_limit = nil
    unset_current_account
    unset_shard_in_env(env)
  end

  private

    def call_next
      @status, @headers, @response = @app.call(@request.env)
    end

    def handle_expiry_not_set
      retry_value = retry_after.to_i
      if retry_value < 0
        Rails.logger.error("Expiry not set properly :: Host: #{@host}, Retry Value: #{retry_value}, Time: #{Time.zone.now}, Count: #{@count}}")
        retry_value = 1
        set_redis_expiry(key, retry_value)
      end
      retry_value
    end

    def shard_not_found?
      @shard.try(:not_found?)
    end

    def throttle_and_proceed
      increment_redis_key(DEFAULT_USED_LIMIT)
      expiry_set = set_redis_expiry(key, api_expiry) if @count <= used_limit # Setting expiry for first time.

      if allowed?
        increment_key_and_proceed(expiry_set)
      else
        retry_value = handle_expiry_not_set
        @status = 429
        @headers = { 'Retry-After' => retry_value.to_s, 'Content-Type' => 'application/json' }
        @response = LIMIT_EXCEEDED_MESSAGE
        log_data("429 Error :: Host: #{@host}, Time: #{Time.zone.now}, Count: #{@count}}, AccountId: #{account_id}", 'error')
      end
    end

    def increment_key_and_proceed(expiry_set)
      @status, @headers, @response = @app.call(@request.env)
      # In order to avoid a 'get' and an 'incrby' call to redis for every request, 'incrby' is being called twice conditionally.
      unless extra_credits.zero?
        increment_redis_key(extra_credits)
        # Expiry should be set immediately after increment, as the expiry condition depends on the incremented value.
        # expiry_set will be true when it is already set in the current request.
        # if expiry happens during @app.call, @count will be less than used_limit. Hence checking '<=' instead of '=='
        set_redis_expiry(key, api_expiry) if !expiry_set && (@count <= used_limit)
      end
      set_rate_limit_headers if @count
    end

    def account_id
      @shard.try(:account_id)
    end

    def api_expiry
      THROTTLE_PERIOD
    end

    def skipped_domain?
      split_host = @host.split('.')
      subdomain = split_host[0]
      domain = split_host[1]
      SKIPPED_SUBDOMAINS.include?(subdomain) && domain == FRESHDESK_DOMAIN
    end

    def throttle?
      if is_fluffy_enabled? || @request.env[HTTP_X_FWI_CLIENT_ID].present?
        false
      else
        !skipped_domain? && account_id
      end
    end

    def increment_redis_key(used)
      @count = increment_redis(key, used.to_i).to_i
    end

    def allowed?
      @shard.try(:ok?) ? @count <= api_limit : true
    end

    def retry_after
      handle_exception { return $rate_limit.perform_redis_op('ttl', key) }
    end

    def extra_credits
      CustomRequestStore.store[:extra_credits] || 0
    end

    def set_rate_limit_headers # Rate Limit headers are not set when status is 429
      remaining = [(api_limit - @count), 0].max.to_s
      @headers = @headers.merge('X-RateLimit-Total' => api_limit.to_s,
                                'X-RateLimit-Remaining' => remaining,
                                'X-RateLimit-Used-CurrentRequest' => used_limit.to_s)
    end

    def set_version_headers
      version = api_version
      @headers = @headers.merge('X-Freshdesk-API-Version' => "latest=#{API_CURRENT_VERSION}; requested=#{version}") if version
    end

    def account_api_limit_key
      format(ACCOUNT_API_LIMIT, account_id: account_id)
    end

    def default_api_limit_key
      DEFAULT_API_LIMIT
    end

    def api_limit
      @api_limit ||= begin
        api_limits = get_multiple_rate_limit_redis_keys(account_api_limit_key, plan_api_limit_key, default_api_limit_key) || []
        (api_limits[0] || api_limits[1] || api_limits[2] || API_LIMIT).to_i
      end
    end

    def plan_api_limit_key
      plan_id = fetch_plan_id
      format(PLAN_API_LIMIT, plan_id: plan_id) if plan_id.present?
    end

    def fetch_plan_id
      Sharding.run_on_shard(@shard.shard_name) do
        Subscription.fetch_by_account_id(account_id).try(:plan_id)
      end
    rescue Exception => e
      Rails.logger.error "Exception while fetching subscription_plan_id :: Host: #{@host}, Message: #{e.message}, Time: #{Time.zone.now}"
      NewRelic::Agent.notice_error(e, custom_params: { description: 'Freshdesk API Throttler Error',
                                                       domain: @host, account_id: account_id })
    end

    def log_data(content, log_type)
      Rails.logger.safe_send(log_type, content)
    end

    def key
      format(API_THROTTLER_V2, account_id: account_id)
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
      shard = ShardMapping.lookup_with_domain(env['HTTP_HOST'])
      # shard = ShardMapping.lookup_with_domain("localhost.freshdesk-dev.com")
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

    def is_fluffy_enabled?
      Account.current && Account.current.fluffy_integration_enabled? && check_fluffy_header
    end

    def skip_on_header
      @request.env[API_THROTTLING_MANAGED] == TRUE_STRING
    end

    def check_fluffy_header
      @request.env[HTTP_X_FW_RATELIMITING_MANAGED] == TRUE_STRING
    end
end
