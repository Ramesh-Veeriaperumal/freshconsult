module Freshid::SnsErrorNotificationExtensions
  def notify_error(subject, error_hash, e = nil)
    subject = "#{Rails.env} :: #{Account.current.try(:id)} :: #{subject}"
    message = "args = #{error_hash.inspect}"
    message += "\n\nEXCEPTION\n#{e.message}\n#{e.backtrace.try(:join, '\n')}" if e
    DevNotification.publish(SNS["freshid_notification_topic"], subject, message)
  end
end
