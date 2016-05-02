class Reports::Export < BaseWorker
  
  sidekiq_options :queue => :report_export_queue, :retry => 0, :backtrace => true, :failures => :exhausted
  

  def perform params
    begin
      old_report = [:timesheet_reports, :chat_summary, :phone_summary]
      class_name = old_report.include?(params['report_type'].to_sym) ? params['report_type'].camelcase : 'Report'
      "HelpdeskReports::Export::#{class_name}".constantize.new(params).perform
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      subj_txt = "Reports Export exception for #{Account.current.id}"
      message  = "#{e.inspect}\n #{e.backtrace.join("\n")}"
      DevNotification.publish(SNS["reports_notification_topic"], subj_txt, message)
    end   
  end
  
end