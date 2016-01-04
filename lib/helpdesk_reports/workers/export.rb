class HelpdeskReports::Workers::Export < BaseWorker
  include HelpdeskReports::Helper::Ticket
  include HelpdeskReports::Export::Utils 
  
  sidekiq_options :queue => :report_export_queue, :retry => 0, :backtrace => true, :failures => :exhausted
  
  def perform params
    HelpdeskReports::Export::Report.new(params).perform
  end
  
end