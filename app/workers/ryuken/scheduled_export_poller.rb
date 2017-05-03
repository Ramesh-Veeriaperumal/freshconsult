class Ryuken::ScheduledExportPoller
  include Shoryuken::Worker

  shoryuken_options queue: ::SQS[:scheduled_ticket_export_complete],
                    body_parser: :json
  
  def perform(sqs_msg, args)
    schedule = Account.current.scheduled_ticket_exports.find_by_id(args["id"]) # TO DO : cache
    if schedule.present?
      schedule.update_column(:latest_file, args["file_name"])
      DataExportMailer.send_later(:scheduled_ticket_export, 
                                  :file_name => args["file_name"], 
                                  :filter_id => args["id"]) if schedule.send_email?
    end
    sqs_msg.try :delete
  rescue Exception => e
    Rails.logger.debug "Error while processing sqs request"
    Rails.logger.debug "#{args} #{e.class} #{e.message} #{e.backtrace}"
    NewRelic::Agent.notice_error(e, 
      {:description => "Error while processing sqs request"})
  end
end
