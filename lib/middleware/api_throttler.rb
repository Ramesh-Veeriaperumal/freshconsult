require 'rack/throttle'

class Middleware::ApiThrottler < Rack::Throttle::Hourly

  include Redis::RedisKeys
  include Redis::OthersRedis
  include MemcacheKeys
  
  SKIPPED_SUBDOMAINS = ["admin", "billing", "partner","signup", "email","login", "emailparser", "mailboxparser","freshops"] + FreshopsSubdomains
  SKIPPED_PATHS      = ["/reports/v2"]
  API_FORMATS        = ['.xml', '.json', 'format=json', 'format=xml']
  THROTTLED_TYPES    = ["application/json", "application/x-javascript", "text/javascript",
                      "text/x-javascript", "text/x-json", "application/xml", "text/xml"]
  ONE_HOUR = 3600

  def initialize(app, options = {})
    super(app, options)
    @app = app
  end

  def allowed?(env)
    begin
      return true if !env['SHARD'].present? || !env['SHARD'].ok?

      Sharding.run_on_shard(env['SHARD'].shard_name) do 
        api_key = API_LIMIT% {:account_id => @account_id}
        api_limit = MemcacheKeys.fetch(api_key) do
          current_account = Account.find(@account_id)
          current_account.api_limit.to_i
        end
        return true if by_pass_throttle?
        remove_others_redis_key(key) if get_others_redis_key(key+"_expiry").nil?
        @count = get_others_redis_key(key).to_i
        return api_limit > @count
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
    @mobihelp_auth = env["HTTP_X_FD_MOBIHELP_APPID"]
    @user_agent ||= env["HTTP_USER_AGENT"]
    @sub_domain = @host.split(".")[0]
    @path_info = env["PATH_INFO"]
    if SKIPPED_SUBDOMAINS.include?(@sub_domain)
      @status, @headers, @response = @app.call(env)
      return [@status, @headers, @response]
    end

    shard = ShardMapping.lookup_with_domain(env["HTTP_HOST"])
    if shard
      env['SHARD'] = shard
      @account_id = shard.account_id
      pod_info = shard.pod_info
    else
      env['SHARD'] = nil
    end

    if PodConfig['CURRENT_POD'] != pod_info
      @status, @headers, @response = @app.call(env)
    elsif allowed? env
      @status, @headers, @response = @app.call(env)
      unless by_pass_throttle?
        remove_others_redis_key(key) if get_others_redis_key(key+"_expiry").nil?
        increment_others_redis(key)
        value = get_others_redis_key(key).to_i
        set_others_redis_key(key+"_expiry",1,ONE_HOUR) if value == 1
      end
    else
      retry_value = retry_after
      Rails.logger.error("API V1 Ratelimit Error :: Account: #{@account_id}, Host: #{@host}, Count: #{@count}, Retry-After: #{retry_value}, Time: #{Time.now}")
      @status, @headers,@response = [403, {'Retry-After' => retry_value,'Content-Type' => 'text/html'}, 
                                      ["You have exceeded the limit of requests per hour"]]
    end
    
     [@status, @headers, @response]
  end

  def by_pass_throttle?
    return true if  SKIPPED_SUBDOMAINS.include?(@sub_domain)
    return true unless @mobihelp_auth.blank?
    return true if @user_agent[/#{AppConfig['app_name']}_Native/].present? 

    SKIPPED_PATHS.each{|p| return true if @path_info.include? p}
    return false if API_FORMATS.any?{|x| @api_path.include?(x)}
    if @content_type
      Rails.logger.debug "Account ID :: #{@account_id} ::: Content type on API:: #{@content_type}" if @account_id
      return !THROTTLED_TYPES.include?(@content_type)
    end
    return true
  end

  def retry_after
    get_others_redis_expiry(key+"_expiry").to_s
  end

  def key
    API_THROTTLER % {:host => @host}
  end

end

