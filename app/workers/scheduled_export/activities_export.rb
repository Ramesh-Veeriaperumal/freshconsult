class ScheduledExport::ActivitiesExport < BaseWorker
  sidekiq_options :queue => :activity_export,
                  :retry => 15,
                  :failures => :exhausted

  DEFAULT_ACTION = 'update'
  DESCRIPTION = "Activities Export SQS push error"

  def perform(args={})
    action = args.present? ? args : DEFAULT_ACTION
    message = build_message
    Shoryuken::Client.queues(SQS[:activity_export_queue]).send_message(message_body: message.merge!({:action => action}))
  rescue => e
    Rails.logger.debug "exception #{message}"
    NewRelic::Agent.notice_error(e, { arguments: message })
    DevNotification.publish(SNS["activities_notification_topic"], DESCRIPTION, message.to_json)
  end

  private

  def build_message
    account = Account.current
    ticket_activity_export = account.activity_export
    schedule_type = ScheduledExport::SCHEDULE_TYPE_BY_VALUE[ticket_activity_export.schedule_type]
    {
        :account_id => account.id,
        :object     => schedule_type,
        :time_zone  => account.time_zone,
        :active     => ticket_activity_export.active,
        :uuid       => generate_uuid
    }
  end

  def generate_uuid
    UUIDTools::UUID.timestamp_create.hexdigest
  end
end
