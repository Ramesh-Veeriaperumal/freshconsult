class HelpdeskReports::Workers::Export < BaseWorker
  include HelpdeskReports::Helper::Ticket
  include HelpdeskReports::Export::Utils 
  
  sidekiq_options :queue => :report_export_queue, :retry => 0, :backtrace => true, :failures => :exhausted
  

  def perform params
    params.symbolize_keys!
    args = { account_id: params[:account_id] , user_id: params[:user_id] }
    HelpdeskReports::Export::Report.new(args).perform(params)
  end
  
end