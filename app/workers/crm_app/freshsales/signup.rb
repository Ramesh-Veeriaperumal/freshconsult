class CRMApp::Freshsales::Signup < CRMApp::Freshsales::BaseWorker

  def perform(args = {})
    args.symbolize_keys!
    execute_on_shard(args[:account_id]){
      freshsales_utility(args, Account.current).push_signup_data(args)
    }
  rescue => e
    Rails.logger.error "Error while pushing account singup to Freshsales 
      args::#{args.inspect} : #{e.message} - #{e.backtrace}" 
    NewRelic::Agent.notice_error(e, { description: "Error occured while 
      pushing account singup to Freshsales args::#{args.inspect}"})
  end

end