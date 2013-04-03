require 'rack/throttle'

class Middleware::ApiThrottler < Rack::Throttle::Hourly

  include RedisKeys
  SKIPPED_URLS = ["admin.freshdesk.com", "billing.freshdesk.com", "partner.freshdesk.com", 
                  "signup.freshdesk.com"]
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
      @count = get_key(API_THROTTLER % {:host => @host}).to_i
      return max_per_hour >= @count
    rescue Exception => e
      true
    end
  end

  def call(env)
    @host = env["HTTP_HOST"]
    @content_type = env['CONTENT-TYPE'] || env['CONTENT_TYPE']

    if allowed?
      @status, @headers, @response = @app.call(env)
      unless by_pass_throttle?
        if @count > 0
          increment(API_THROTTLER % {:host => @host})
        else
          set_key(API_THROTTLER % {:host => @host}, 1, ONE_HOUR)
        end
      end
    else
      @status, @headers, @response = [302, {"Location" => "/403.html"}, 
                                      'You have exceeded the limit of requests per hour']
    end
    
     [@status, @headers, @response]
  end

  def by_pass_throttle?
    SKIPPED_URLS.include?(@host) || !THROTTLED_TYPES.include?(@content_type)
  end

end

