class Workers::Webhook
  extend Resque::AroundPerform
  extend Va::Webhook::ThrottlerUtil

  RETRY_DELAY = 30.minutes.to_i
  RETRY_LIMIT = Rails.env.test? ? 0 : 4
  SUCCESS     = 200..299
  REDIRECTION = 300..399

  @queue = 'webhook_worker'
  
  class << self  
    def perform args
      begin
        response = HttpRequestProxy.new.fetch_using_req_params( args[:params].symbolize_keys,
                                                                args[:auth_header].symbolize_keys )
        case response[:status]
        when SUCCESS
        when REDIRECTION
          Rails.logger.debug "Redirected : Won't be re-enqueued and pursued"
        else 
          if args[:retry_count] < RETRY_LIMIT
            args = {  :params => args[:params], :auth_header => args[:auth_header], 
                      :retry_count => args[:retry_count]+1 }
            throttler_args = {  :worker => Workers::Webhook.to_s, :args => args, :key => key, 
                                :expire_after => THROTTLE_EVERY,   :limit => THROTTLE_LIMIT, 
                                :retry_after => RETRY_DELAY }
            Resque.enqueue(Workers::Throttler, throttler_args)
          end
        end 
      rescue Exception => e
        puts "Something is wrong in Webhook::Worker : #{e.message}"
      end
    end
  end

end