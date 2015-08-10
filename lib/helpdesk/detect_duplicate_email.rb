module Helpdesk::DetectDuplicateEmail

  include Redis::RedisKeys

  MAIL_PROCESS_TIME = 1800

  def process_email_key(message_id=nil)
    PROCESS_EMAIL_PROGRESS % { :account_id =>  Account.current.id, 
                               :unique_key => message_id || get_message_id || received_time.to_i}
  end

  # Mailgun gives us the message id in the params with "Message-Id" key
  # For sendgrid, we'll extract it from the headers in ProcessByMessageId
  def get_message_id
    params["Message-Id"] ? params["Message-Id"][1..-2] : message_id
  end
  
  def duplicate_email?(from, to, subject, message_id)
    value = get_others_redis_hash process_email_key(message_id)
    if value.present? && value == { "from" => from, 
                                    "to" => to, 
                                    "subject" => subject, 
                                    "message_id" => message_id }
      subject = "ProcessEmail :: Duplicate Email in account_id #{Account.current.id}"
      msg = "Duplicate Email in account_id #{Account.current.id} with subject : #{subject}
                                                                        from  : #{from}
                                                                        to    : #{to}
                                                                  message_id  : #{message_id}"
      NewRelic::Agent.notice_error msg
      Rails.logger.debug msg
      DevNotification.publish(email_topic, subject, msg)
      true
    end
  end

  def received_time
    @received_time ||= begin
      if params[:internal_date] # From custom mailbox
        params[:internal_date].to_time
      elsif params["timestamp"] # Mailgun gives the timestamp in params
        Time.at(params["timestamp"]).utc
      else
        calculate_received_time # Calculating from headers for Sendgrid
      end
    end
  end

  def calculate_received_time
    headers = Mail::Header.new params[:headers]
    headers[:received][0].to_s.to_time if headers[:received].any?
  rescue Exception => e
    subject = "ProcessEmail :: Received Time Calculation Error - Account ID #{Account.current.id}"
    msg     = {
      :account_id => Account.current.id,
      :subject    => params[:subject],
      :headers    => params[:headers]
    }
    NewRelic::Agent.notice_error(e, msg)
    Rails.logger.debug msg.to_json
    DevNotification.publish(email_topic, subject, msg.to_json)
    nil
  end

  def email_topic
    SNS["mailbox_notification_topic"]
  end
end
