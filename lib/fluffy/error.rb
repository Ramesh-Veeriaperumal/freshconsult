class Fluffy::Error

  FLUFFY_ERROR = 'FLUFFY_REQUEST_FAILED'

  class << self
    def log(error_info, exception=nil)
      Rails.logger.error "INFO=#{error_info.inspect}"
      Rails.logger.error "EXP=#{exception.message}\n#{exception.backtrace.try(:join, '\n')}" if exception.present?
      notify_error(FLUFFY_ERROR, error_info, exception)
    end

    def notify_error(subject, error_hash, exp = nil)
      subject = "#{Rails.env} :: #{Account.current.try(:id)} :: #{subject}"
      message = "args = #{error_hash.inspect}"
      message += "\n\nEXCEPTION\n#{exp.message}\n#{exp.backtrace.try(:join, '\n')}" if exp
      DevNotification.publish(SNS["fluffy_notification_topic"], subject, message)
    end
  end
end