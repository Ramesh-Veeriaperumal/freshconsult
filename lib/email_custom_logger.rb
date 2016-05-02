module EmailCustomLogger
  def email_log_file
    "#{Rails.root}/log/email_app.log"
  end

  def email_logger
    @@email_logger ||= ActiveSupport::TaggedLogging.new(CustomLogger.new(email_log_file))
  end
end
