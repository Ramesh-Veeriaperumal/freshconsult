class CRMApp::Freshsales::DeletedCustomer < CRMApp::Freshsales::BaseWorker

  def perform(args = {})
    args.symbolize_keys!
    ThirdCRM.new.update_lead_info(args[:admin_email])
    freshsales_utility(args, Account.current).account_cancellation
  rescue => e
    Rails.logger.error "Error while pushing account cancellation to Freshsales 
      args::#{args.inspect} \n #{e.message} - #{e.backtrace}" 
    NewRelic::Agent.notice_error(e, { description: "Error occured while 
      pushing cancellation Info to Freshsales args::#{args.inspect}"})
  end
  
end