require 'rack/throttle'

class Middleware::ApiThrottler < Rack::Throttle::Hourly

  include Redis::RedisKeys
  include Redis::OthersRedis
  include MemcacheKeys
  
  SKIPPED_SUBDOMAINS = ["admin", "billing", "partner","freshsignup", "email","login", "emailparser", "mailboxparser"] 
  THROTTLED_TYPES = ["application/json", "application/x-javascript", "text/javascript",
                      "text/x-javascript", "text/x-json", "application/xml", "text/xml"]
  ALLOWED_PATHS = [/\/integrations\/.*/]
  ONE_HOUR = 3600

  def initialize(app, options = {})
    super(app, options)
    @app = app
  end

  def call(env)
    @request = Rack::Request.new(env)
    @host = env["HTTP_HOST"]
    @sub_domain = @host.split(".")[0]
    @api_path = env["REQUEST_URI"].to_s
    @content_type = env['CONTENT-TYPE'] || env['CONTENT_TYPE']

    if SKIPPED_SUBDOMAINS.include?(@sub_domain)
      @status, @headers, @response = @app.call(env)
      return [@status, @headers, @response]
    end

    if throttle?
      @count = increment_others_redis(key)
      ### Notify dev-ops if count exceeds threshold?
      set_others_redis_expiry(key, ONE_HOUR) if @count == 1
      
      if !allowed?
        @status, @headers,@response = [403, {'Retry-After' => retry_after,'Content-Type' => 'text/html'}, 
                                      ["You have exceeded the limit of requests per hour"]]
      elsif !@in_app_request and !THROTTLED_TYPES.include?(@content_type)
        @status, @headers,@response = [415, {'Content-Type' => 'text/html'}, ["Invalid Content-Type"]]
      else
        @status, @headers, @response = @app.call(@request.env)
      end
    else
      @status, @headers, @response = @app.call(@request.env)
    end
    
     [@status, @headers, @response]
  end

  def api_path?
    @api_path.include?(".xml") or @api_path.include?(".json")
  end

  def throttle?
    if app_request? or first_web_request? or is_native_mobile? or is_mobihelp? or allowed_paths_call?
      @in_app_request = true
      (api_path? ? true : false)
    else
      Rails.logger.debug "SOURCE IP :: #{@request.env["HTTP_X_REAL_IP"]}, Content type on API :: #{@content_type}"
      return true
    end
  end

  def app_request?
    @request.env["HTTP_X_CSRF_TOKEN"].present? or
    @request.cookies["_helpkit_session"].present?
  end

  def first_web_request?
    @request.get? and @request.env["HTTP_ACCEPT"].to_s.include?('application/xhtml+xml')
  end

  def is_native_mobile?
    @request.env["HTTP_USER_AGENT"].to_s[/#{AppConfig['app_name']}_Native/].present? and 
    (@api_path.include?('user_session') or @request.env["HTTP_AUTHORIZATION"].to_s[/Basic .*/].present?)
  end

  def is_mobihelp?
    @request.env["HTTP_X_FD_MOBIHELP_AUTH"].present? and 
    (@api_path[/\/support\/mobihelp\/.*/] or @api_path[/\/mobihelp\/.*/]).present?
  end

  def allowed_paths_call?
    @api_path.match(Regexp.union(ALLOWED_PATHS)).present?
  end

  def allowed?
    begin
      domain = DomainMapping.find_by_domain(@request.env["HTTP_HOST"])
      account_id = domain.account_id if domain

      Sharding.select_shard_of(account_id) do 
        api_limit = MemcacheKeys.fetch((API_LIMIT % {:account_id => account_id})) do
          Account.find(account_id).api_limit.to_i
        end

        return (@count <= api_limit)
      end
    rescue Exception => e
      Rails.logger.debug "Exception on api throttler ::: #{e.message}"
      NewRelic::Agent.notice_error(e,{ :custom_params => { 
                                                            :description => "API Throttler Error", 
                                                            :domain => domain,
                                                            :account_id => account_id 
                                                          }})
      return true
    end
  end

  def retry_after
    get_others_redis_expiry(key).to_s
  end

  def key
    API_THROTTLER % {:host => @host}
  end

end