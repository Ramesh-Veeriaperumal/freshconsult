require 'rack/throttle'

class Middleware::ApiThrottler < Rack::Throttle::Hourly

  include RedisKeys
  SKIPPED_SUBDOMAINS = ["admin", "billing", "partner","signup", "email"] 
  THROTTLED_TYPES = ["application/json", "application/x-javascript", "text/javascript",
                      "text/x-javascript", "text/x-json", "application/xml", "text/xml"]
  ONE_HOUR = 3600

  def initialize(app, options = {})
    super(app, options)
    @app = app
  end

  def allowed?
    begin
      return true if by_pass_throttle?
      remove_key(key) if get_key(key+"_expiry").nil?
      @count = get_key(key).to_i
      return max_per_hour > @count
    rescue Exception => e
      true
    end
  end

  def call(env)
    @host = env["HTTP_HOST"]
    @content_type = env['CONTENT-TYPE'] || env['CONTENT_TYPE']
    @api_path = env["REQUEST_URI"]
    @sub_domain = @host.split(".")[0]

    if allowed?
      @status, @headers, @response = @app.call(env)
      unless by_pass_throttle?
        remove_key(key) if get_key(key+"_expiry").nil?
        increment(key)
        value = get_key(key).to_i
        set_key(key+"_expiry",1,ONE_HOUR) if value == 1
      end
    else
      @status, @headers, @response = [302, {"Location" => "/403.html"}, 
                                      'You have exceeded the limit of requests per hour']
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

  def key
    API_THROTTLER % {:host => @host}
  end

end

