class ScheduledExport::Ticket::Config < BaseWorker
  sidekiq_options :queue => :scheduled_ticket_export_config, 
                  :retry => 2,
                  :failures => :exhausted

  def perform args
    args.symbolize_keys!
    if args[:action].to_sym != :destroy
      schedule = Account.current.scheduled_ticket_exports.find_by_id(args[:filter_id])
      return if schedule.nil?
      args.merge!(schedule.params_for_service)
    end
    $sqs_scheduled_ticket_export.send_message(args.to_json)
  rescue Exception => e
    Rails.logger.debug "Error in sending ticket schedule config data to SQS"
    Rails.logger.debug "#{args} #{e.class} #{e.message} #{e.backtrace}"
    NewRelic::Agent.notice_error(e, 
      {:description => "Error in sending ticket schedule config data to SQS"})
  end
end
