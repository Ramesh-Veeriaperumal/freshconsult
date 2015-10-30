require 'rack/throttle'

class Middleware::ApiThrottler < Rack::Throttle::Hourly

  include Redis::RedisKeys
  include Redis::OthersRedis
  include MemcacheKeys
  
  SKIPPED_SUBDOMAINS = ["admin", "billing", "partner","signup", "email","login", "emailparser", "mailboxparser","freshops"] 
  SKIPPED_PATHS      = ["/reports/v2"]
  THROTTLED_TYPES = ["application/json", "application/x-javascript", "text/javascript",
                      "text/x-javascript", "text/x-json", "application/xml", "text/xml"]
  ONE_HOUR = 3600
  FD_API_LIMIT_CONSTANT = 1000
  FD_DEFAULT_USED_LIMIT_CONSTANT = 1

  def initialize(app, options = {})
    super(app, options)
    @app = app
  end

  def allowed?
    begin
      Sharding.select_shard_of(@account_id) do 
        current_account = Account.find(@account_id)
        if @api_resource # Retrieve api_limit from redis
          @api_limit = get_api_limit(current_account)
        else
          api_key = API_LIMIT% {:account_id => @account_id}
          @api_limit = MemcacheKeys.fetch(api_key) do
            current_account.api_limit.to_i
          end
        end
        return true if by_pass_throttle?
        remove_others_redis_key(key) if get_others_redis_key(key+"_expiry").nil?
        @count = get_others_redis_key(key).to_i
        return @api_limit > @count
      end
    rescue Exception => e
      Rails.logger.debug "Exception on api throttler ::: #{e.message}"
      NewRelic::Agent.notice_error(e)
      true
    end
  end

  def call(env)
    @host = env["HTTP_HOST"]
    @content_type = env['CONTENT-TYPE'] || env['CONTENT_TYPE']
    @api_path = env["REQUEST_URI"]
    @api_resource = env["PATH_INFO"].starts_with?('/api/')
    @mobihelp_auth = env["HTTP_X_FD_MOBIHELP_APPID"]
    @sub_domain = @host.split(".")[0]
    @path_info = env["PATH_INFO"]
    if SKIPPED_SUBDOMAINS.include?(@sub_domain)
      @status, @headers, @response = @app.call(env)
      return [@status, @headers, @response]
    end
    domain = DomainMapping.find_by_domain(env["HTTP_HOST"])
    @account_id = domain.account_id if domain
    if allowed?
      @status, @headers, @response = @app.call(env)
      unless by_pass_throttle?
        remove_others_redis_key(key) if get_others_redis_key(key+"_expiry").nil?
        # Except V1, other versions will have different credits associated with a single request, hence increment_other_redis_by_value is implemented.
        @api_resource ? increment_other_redis_by_value(key, get_used_limit.to_i) : increment_others_redis(key)
        value = get_others_redis_key(key).to_i
        set_others_redis_key(key+"_expiry",1,ONE_HOUR) if value == 1
      end
    elsif @api_resource
      error_output = "You have exceeded the limit of requests per hour"
      @status, @headers,@response = [429, {'Retry-After' => retry_after, 'Content-Type' => 'application/json'}, 
                                      [{:message => error_output}.to_json]]
      Rails.logger.error("API 429 Error. Time: #{Time.now}, Host: #{env["HTTP_HOST"]}")
    else
      @status, @headers,@response = [403, {'Retry-After' => retry_after,'Content-Type' => 'text/html'}, 
                                      ["You have exceeded the limit of requests per hour"]]
    end
    # Setting API Limit headers for API
    if @api_resource && @api_limit
      set_rate_limit_version_headers(env)
    end
     [@status, @headers, @response]
  end

  def set_rate_limit_version_headers(env)
    @headers = @headers.merge("X-RateLimit-Total" => @api_limit.to_s,
                      "X-RateLimit-Remaining" => [(@api_limit - get_others_redis_key(key).to_i), 0].max.to_s,
                      "X-RateLimit-Used" => get_used_limit.to_s)
      version = get_api_version(env)
      @headers = @headers.merge('X-Freshdesk-API-Version' => "latest=#{ApiConstants::API_CURRENT_VERSION}; requested=#{version}") if version
  end

  def by_pass_throttle?
    return true if  SKIPPED_SUBDOMAINS.include?(@sub_domain)
    return true unless @mobihelp_auth.blank?
    SKIPPED_PATHS.each{|p| return true if @path_info.include? p}
    return false if @api_resource
    if @content_type.nil?
      return ( !@api_path.include?(".xml") && !@api_path.include?(".json") )
    else
      Rails.logger.debug "Account ID :: #{@account_id} ::: Content type on API:: #{@content_type}" if @account_id
      return !THROTTLED_TYPES.include?(@content_type)
    end
  end

  def retry_after
    get_others_redis_expiry(key+"_expiry").to_s
  end

  def key
    @api_resource ? VERSIONED_API_THROTTLER % {:host => @host} : API_THROTTLER % {:host => @host}
  end

  def account_api_limit_key
    FD_ACCOUNT_API_LIMIT % {:host => @host}
  end

  def plan_api_limit_key(plan_id)
    FD_PLAN_API_LIMIT % {:plan_id => plan_id}
  end

  def default_api_limit_key
    FD_DEFAULT_API_LIMIT
  end

  def get_api_limit(account)
    api_limits = get_multiple_other_redis_keys(account_api_limit_key, default_api_limit_key)
    (api_limits.first || get_plan_api_limit(account) || api_limits.last || FD_API_LIMIT_CONSTANT).to_i 
  end

  def get_plan_api_limit(account)
    # Can we cache subscription of an account?
    plan_id = account.subscription_from_cache.plan_id
    get_others_redis_key(plan_api_limit_key(plan_id))
  end

  def get_used_limit
    @used = RequestStore.store[:api_credits] || FD_DEFAULT_USED_LIMIT_CONSTANT
  end

  def get_api_version(env)
    return if @status == 404
    env["action_dispatch.request.path_parameters"].try(:[], :version)
  end
end

