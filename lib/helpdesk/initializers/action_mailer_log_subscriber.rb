require 'action_mailer'

module ActionMailer
  class LogSubscriber
    include EmailCustomLogger

    def deliver(event)
      recipients = Array.wrap(event.payload[:to]).join(', ')
      logger.info("Sent mail to #{recipients} (%1.fms)" % event.duration)
      logger.info("Headers : #{extract_header(event.payload[:mail])}")
      email_logger.debug(event.payload[:mail])
    end

    def extract_header(original_str)
      original_str =~ /(.+?)(\r\n\r\n)/m ? $1 : ""
      original_str.gsub!("\r\n", "\\r\\n")
    end
  end
end
