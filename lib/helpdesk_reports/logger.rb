class HelpdeskReports::Logger

  class << self

    def log(subject, exception=nil, options=nil)
      if exception.is_a?(Exception)
        subject = "Reports | Error - #{subject} - #{Time.now.utc}"
        message = "#{subject} \n #{exception.message} \n #{(exception.backtrace||[]).join("\n")} \n #{options.inspect}"
        sns_notification(subject[0..90], message)
        NewRelic::Agent.notice_error(exception, {
        :custom_params => {
          :description => subject,
          :message     => message
        }})
        Rails.logger.error(message)
      else
        message = "Reports | Info - #{subject} - #{Time.now.utc}"
        Rails.logger.info(message)
      end
    rescue => e
      NewRelic::Agent.notice_error(e, {:custom_params => {:description => subject, :options => options}})
    end

    def sns_notification(subj, message)
      DevNotification.publish(SNS["reports_notification_topic"], subj, message.to_json)
    end

  end

end