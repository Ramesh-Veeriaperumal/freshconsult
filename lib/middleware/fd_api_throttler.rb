require 'rack/throttle'

class Middleware::FdApiThrottler < Rack::Throttle::Hourly

  include Redis::RedisKeys
  include MemcacheKeys

  SKIPPED_SUBDOMAINS =  ["admin", "billing", "partner", "signup", "freshsignup", "email","login", "emailparser", "mailboxparser"]
  THROTTLED_TYPES    =  ["application/json", "application/x-javascript", "text/javascript",
                         "text/x-javascript", "text/x-json", "application/xml", "text/xml"]
  ALLOWED_PATHS      =  ["/integrations", "/freshfone"]
  THROTTLE_PERIOD    =  1.hour

  def initialize(app, options = {})
    super(app, options)
    @app = app
  end

  def call(env)
    @request      = Rack::Request.new(env)
    @host         = env["HTTP_HOST"]
    @sub_domain   = @host.split(".")[0]
    @api_path     = env["REQUEST_PATH"].to_s
    @content_type = env['CONTENT-TYPE'] || env['CONTENT_TYPE']
    shard         = ShardMapping.lookup_with_domain(@host)

    if shard.try(:blocked?)
      Rails.logger.debug "FdApiThrottler :: Domain blocked :: #{@host} (#{@count})"
      #-Uncomment when going for prod-
      # @status, @headers,@response = [403, {'Content-Type' => 'text/html'}, ["Your domain has been blocked."]]
    elsif !skipped_domain? and throttle?
      @count = increment_redis(key)
      #Notify dev-ops if request hits 1005?
      set_redis_expiry(key, THROTTLE_PERIOD) if @count == 1

      if !allowed?(shard)
        Rails.logger.debug "FdApiThrottler :: Limit Exceeded :: #{@host} (#{@count})"
        #-Uncomment when going for prod-
        # @status, @headers,@response = [403, {'Retry-After' => retry_after,'Content-Type' => 'text/html'},
                                       # ["You have exceeded the limit of requests per hour"]]
      # Commenting out as iOS app was breaking
      # elsif !@in_app_request and !THROTTLED_TYPES.include?(@content_type)
      #   @status, @headers,@response = [415, {'Content-Type' => 'text/html'}, ["Invalid Content-Type"]]
      else
        Rails.logger.debug "FdApiThrottler :: Throttled :: #{@host} (#{@count})"
        #-Uncomment when going for prod-
        # @status, @headers, @response = @app.call(@request.env)
      end
    else
      #-Uncomment when going for prod-
      # @status, @headers, @response = @app.call(@request.env)
    end

    @status, @headers, @response = @app.call(@request.env) #-Remove when going to prod-
    [@status, @headers, @response]

  ensure
    @in_app_request = false
  end

  private

    def skipped_domain?
      SKIPPED_SUBDOMAINS.include?(@sub_domain)
    end

    def api_path?
      @api_path.include?(".xml") or @api_path.include?(".json")
    end

    def throttle?
      if app_request? or first_web_request? or native_mobile? or mobihelp? or allowed_paths_call?
        @in_app_request = true
        (api_path? ? true : false)
      else
        Rails.logger.debug "SOURCE IP :: #{@request.env["HTTP_X_REAL_IP"]}, DOMAIN :: #{@host}, Content type on API :: #{@content_type}"
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

    def native_mobile?
      @request.env["HTTP_USER_AGENT"].to_s[/#{AppConfig['app_name']}_Native/].present? and
          (@api_path.include?('user_session') or @request.env["HTTP_AUTHORIZATION"].to_s[/Basic .*/].present?)
    end

    def mobihelp?
      @request.env["HTTP_X_FD_MOBIHELP_AUTH"].present? and
          (@api_path.starts_with?("/support/mobihelp") or @api_path.starts_with?("/mobihelp")).present?
    end

    def allowed_paths_call?
      @api_path.starts_with?(*ALLOWED_PATHS)
    end

    def allowed?(shard)
      if shard.try(:ok?)
        account_id = shard.account_id
        begin
          Sharding.run_on_shard(shard.shard_name) do 
            api_limit = MemcacheKeys.fetch(API_LIMIT % {:account_id => account_id}) do
              Account.find(account_id).api_limit.to_i
            end 

            return (@count <= api_limit)
          end
        rescue Exception => e
          Rails.logger.debug "Exception on api throttler ::: #{e.message}"
          NewRelic::Agent.notice_error(e,{ :custom_params => {
                                         :description => "Freshdesk API Throttler Error",
                                         :domain      => @host,
                                         :account_id  => account_id
          }})
          return true
        end
      else
        return true
      end
    end

    def increment_redis(key)
      newrelic_begin_rescue { return $spam_watcher.INCR(key) }
    end

    def set_redis_expiry(key, expires)
      newrelic_begin_rescue { $spam_watcher.expire(key, expires) }
    end

    def retry_after
      newrelic_begin_rescue { return $spam_watcher.ttl(key) }
    end

    def key
      API_THROTTLER % {:host => @host}
    end
end
