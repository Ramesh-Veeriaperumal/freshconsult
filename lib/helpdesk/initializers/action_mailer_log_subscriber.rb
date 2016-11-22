require 'action_mailer'

module ActionMailer
  class LogSubscriber
    include EmailCustomLogger

    def deliver(event)
      unless (event.payload.key?(:exception))
        recipients_array = event.payload[:to].dup
        recipients_array.push(event.payload[:cc]) if event.payload[:cc]
        recipients_array.push(event.payload[:bcc]) if event.payload[:bcc]
        recipients = Array.wrap(recipients_array).join(', ')
        from = Array.wrap(event.payload[:from]).join(', ')
        logger.info("Sent mail From #{from} to #{recipients} (%1.fms)" % event.duration)
        logger.info("Headers : #{extract_header(event.payload[:mail])}")
        email_logger.debug(event.payload[:mail])
      else
        logger.info("Email Sending Failed due to : #{event.payload[:exception]}")
      end
    end

    def extract_header(original_str)
      original_str =~ /(.+?)(\r\n\r\n)/m ? $1 : ""
      original_str.gsub!("\r\n", "\\r\\n")
    end
  end
end
