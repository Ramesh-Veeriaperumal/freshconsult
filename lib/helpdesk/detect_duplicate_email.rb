module Helpdesk::DetectDuplicateEmail

  include Redis::RedisKeys

  MAIL_PROCESS_TIME = 1800

  def process_email_key
    PROCESS_EMAIL_PROGRESS % { :account_id =>  Account.current.id, 
                               :unique_key => get_message_id || received_time.to_i}
  end

  # Mailgun gives us the message id in the params with "Message-Id" key
  # For sendgrid, we'll extract it from the headers in ProcessByMessageId
  def get_message_id
    params["Message-Id"] ? params["Message-Id"][1..-2] : message_id
  end
  
  def duplicate_email?(from, to, subject, message_id)
    value = get_others_redis_hash process_email_key
    if value.present? && value == { "from" => from, 
                                    "to" => to, 
                                    "subject" => subject, 
                                    "message_id" => message_id }
      msg = "Duplicate Email in account_id #{Account.current.id} with subject : #{subject}
                                                                        from  : #{from}
                                                                        to    : #{to}
                                                                  message_id  : #{message_id}"
      NewRelic::Agent.notice_error msg
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
    FreshdeskErrorsMailer.send_later(:error_email, nil, e.backtrace, e, 
                                     { :subject => "Process Email Error - #{e.class}" })
    nil
  end
end
