class CRMApp::Freshsales::AdminUpdate < CRMApp::Freshsales::BaseWorker

  def perform(args = {})
    args.symbolize_keys!
    execute_on_shard(args[:account_id]){
      freshsales_utility(args, Account.current).update_admin_info
    }
  rescue ShardNotFound => e
    Rails.logger.error "ShardNotFound exception while pushing AdminUpdate Info 
      to Freshsales args::#{args.inspect} : #{e.message} - #{e.backtrace}"
  rescue => e
    Rails.logger.error "Error occured while pushing AdminUpdate Info 
      to Freshsales args::#{args.inspect} : #{e.message} - #{e.backtrace}" 
    NewRelic::Agent.notice_error(e, { description: "Error occured while 
      pushing AdminUpdate Info to Freshsales args::#{args.inspect}" })
    raise e
  end

end