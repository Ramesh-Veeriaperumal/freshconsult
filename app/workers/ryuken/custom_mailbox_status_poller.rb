class CustomMailboxStatusPoller
  include Shoryuken::Worker
  shoryuken_options queue: SQS[:custom_mailbox_status], body_parser: :json

  def perform(sqs_msg, args)
    begin
      message = JSON.parse(sqs_msg.body).deep_symbolize_keys
      process message if valid_message? message
      sqs_msg.try :delete
    rescue => e
      NewRelic::Agent.notice_error(e, description: "Error while processing sqs request for message #{sqs_msg.body}")
      Rails.logger.error "Error while processing sqs request for message: #{e.inspect} #{e.backtrace.join("\n\t")}"
    end
  end

  def process(message)
    email_config = Account.current.email_configs.where(to_email: message[:to_email]).first
    if email_config.blank? || email_config.imap_mailbox.blank?
      log_error(message, 'custom mailbox status : Email config or IMAP mailbox missing')
      return
    end
    if message[:status] == 'failed'
      if (error_type = message[:error].try(:[], :code).to_i.try(:nonzero?))
        if Admin::EmailConfig::Imap::KNOWN_ERROR_MAP.keys.include?(error_type)
          update_error_type(email_config, error_type, message)
        else
          update_error_type(email_config, Admin::EmailConfig::Imap::UNKNOWN_ERROR_TYPE, message)
          log_error(message, 'custom mailbox status : Unknown error type')
        end
      else
        log_error(message, 'custom mailbox status : Status is failed but error code is not present or not valid')
      end
    elsif message[:status] == 'running'
      update_error_type(email_config, Admin::EmailConfig::Imap::RUNNING, message)
    elsif message[:status] == 'suspended'
      update_error_type(email_config, Admin::EmailConfig::Imap::SUSPENDED, message)
    end
  end

  def valid_message?(message)
    unless validate_keys?(message)
      log_error(message, 'custom mailbox status : Message validation failed mandatory keys are missing')
      return false
    end
    unless Admin::EmailConfig::Imap::STATUS.include? message[:status]
      log_error(message, 'custom mailbox status : Invalid state in notification')
      return false
    end
    true
  end

  def validate_keys?(args)
    Admin::EmailConfig::Imap::MANDATORY_FIELDS.all? {|mandatory_key| (args.key?(mandatory_key) && args[mandatory_key].present?)}
  end

  def update_error_type(email_config, error_type, message)
    email_config.imap_mailbox.tap do |imap_mailbox|
      if imap_mailbox.error_type != error_type
        imap_mailbox.error_type = error_type
        imap_mailbox.save
        Rails.logger.info("custom mailbox status : updating the error_type for account : #{Account.current.id}, mailbox_id : #{imap_mailbox.id}, value : #{error_type}")
      else
        Rails.logger.info("custom mailbox status : Same error type as before #{message.inspect}")
      end
    end
  end

  private

  def log_error(message, error_message)
    Rails.logger.error("#{error_message} #{message.inspect}")
    NewRelic::Agent.notice_error("#{error_message}  #{message.inspect}")
  end

end


