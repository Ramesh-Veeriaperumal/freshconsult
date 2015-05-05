require 'rack/throttle'

class Middleware::ApiThrottler < Rack::Throttle::Hourly

  include Redis::RedisKeys
  include Redis::OthersRedis
  include MemcacheKeys
  
  SKIPPED_SUBDOMAINS = ["admin", "billing", "partner","signup", "email","login", "emailparser", "mailboxparser","freshops"] 
  THROTTLED_TYPES = ["application/json", "application/x-javascript", "text/javascript",
                      "text/x-javascript", "text/x-json", "application/xml", "text/xml"]
  ONE_HOUR = 3600

  def initialize(app, options = {})
    super(app, options)
    @app = app
  end

  def allowed?
    begin
      Sharding.select_shard_of(@account_id) do 
        current_account = Account.find(@account_id)
        api_key = API_LIMIT% {:account_id => @account_id}
        api_limit = MemcacheKeys.fetch(api_key) do
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
    @api_resource = env["PATH_INFO"]
    @mobihelp_auth = env["HTTP_X_FD_MOBIHELP_APPID"]
    @sub_domain = @host.split(".")[0]
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
        increment_others_redis(key)
        value = get_others_redis_key(key).to_i
        set_others_redis_key(key+"_expiry",1,ONE_HOUR) if value == 1
      end
    elsif  @content_type =~ /application\/json/ || @api_resource.starts_with?('/api/')
      error_output = "You have exceeded the limit of requests per hour"
      @status, @headers,@response = [429, {'Retry-After' => retry_after, 'Content-Type' => 'application/json'}, 
                                      {:message => error_output}.to_json]
    else
      @status, @headers,@response = [403, {'Retry-After' => retry_after,'Content-Type' => 'text/html'}, 
                                      ["You have exceeded the limit of requests per hour"]]
    end
    
     [@status, @headers, @response]
  end

  def by_pass_throttle?
    return true if  SKIPPED_SUBDOMAINS.include?(@sub_domain)
    return true unless @mobihelp_auth.blank?
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
    API_THROTTLER % {:host => @host}
  end

end

