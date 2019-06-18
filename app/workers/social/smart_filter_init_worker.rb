class Social::SmartFilterInitWorker < BaseWorker
  include Social::SmartFilter
  include Social::Util
  sidekiq_options queue: :smart_filter_initialise,
                  retry: true,
                  failures: :exhausted

  def perform(args)   
    args.symbolize_keys!
    begin
      response = smart_filter_initialize(args[:smart_filter_init_params])
    rescue Exception => e
      handle_failure(e, args)
    end      
  end

  def handle_failure(response, args)
    notify_social_dev("Error initializing smart filter", {:msg => "Account_ID: #{Account.current.id} Params: #{args} :: Response code: #{response}"}) 
    unless response.is_a?(RestClient::Exception) && response.http_code.between?(400, 499)
      raise "Error initializing smart filter Account_ID: #{Account.current.id}"
    end
  end
end