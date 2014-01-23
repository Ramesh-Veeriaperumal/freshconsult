require 'rack/throttle'

class Middleware::ApiThrottler < Rack::Throttle::Hourly

  include Redis::RedisKeys
  include Redis::OthersRedis
  include MemcacheKeys
  
  SKIPPED_SUBDOMAINS = ["admin", "billing", "partner","signup", "email","login", "emailparser"] 
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
        key = API_LIMIT% {:account_id => @account_id}
        api_limit = MemcacheKeys.fetch(key) do
          current_account.api_limit.to_i
        end
        return true if by_pass_throttle?
        remove_others_redis_key(key) if get_others_redis_key(key+"_expiry").nil?
        @count = get_others_redis_key(key).to_i
        return api_limit > @count
      end
    rescue Exception => e
      true
    end
  end

  def call(env)
    @host = env["HTTP_HOST"]
    @content_type = env['CONTENT-TYPE'] || env['CONTENT_TYPE']
    @api_path = env["REQUEST_URI"]
    @sub_domain = @host.split(".")[0]
    domain = DomainMapping.find_by_domain(env["HTTP_HOST"])
    return [@status, @headers, @response] if domain.nil? && !Rails.env.development?
    @account_id =  Rails.env.development? ? Account.first.id : domain.account_id  
    if allowed?
      @status, @headers, @response = @app.call(env)
      unless by_pass_throttle?
        remove_others_redis_key(key) if get_others_redis_key(key+"_expiry").nil?
        increment_others_redis(key)
        value = get_others_redis_key(key).to_i
        set_others_redis_key(key+"_expiry",1,ONE_HOUR) if value == 1
      end
    else
      @status, @headers,@response = [403, {'Retry-After' => retry_after,'Content-Type' => 'text/html'}, 
                                      ["You have exceeded the limit of requests per hour"]]
    end
    
     [@status, @headers, @response]
  end

  def by_pass_throttle?
    return true if  SKIPPED_SUBDOMAINS.include?(@sub_domain)
    if @content_type.nil?
      return ( !@api_path.include?(".xml") && !@api_path.include?(".json") )
    else
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

