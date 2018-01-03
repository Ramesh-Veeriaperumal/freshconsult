class Social::SmartFilterInitWorker < BaseWorker
  include Social::SmartFilter
  include Social::Util
  sidekiq_options :queue => :smart_filter_initialise, 
                  :retry => 0,
                  :backtrace => true, 
                  :failures => :exhausted

  def perform(args)   
    args.symbolize_keys!
    Sharding.select_shard_of(args[:account_id]) do
      @account = Account.find(args[:account_id]).make_current
      response = smart_filter_initialize(args[:smart_filter_init_params])
      if response != 201
        handle_failure(response, args) 
      end
    end
  end

  def handle_failure(response, args)
    notify_social_dev("Error initializing smart filter", {:msg => "Account_ID: #{Account.current.id} Params: #{args} :: Response code: #{response}"}) 
    if response.is_a?(Integer) && !(response.between?(400, 499))
      Social::SmartFilterInitWorker.perform_in(2.minutes.from_now, args)
    end
  end
end