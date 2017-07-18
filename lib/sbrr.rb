module SBRR

  def self.log_path
    "#{Rails.root}/log/sbrr.log"
  end

  def self.logger
    @@sbrr_logger ||= Logger.new(log_path)
  end

  def self.log text
    log_text = "\n#{Thread.current[:sbrr_log]} #{Thread.current[:mass_assignment]} #{"%.5f" % Time.now.to_f}  #{text}"
    logger.debug log_text if Thread.current[:sbrr_log]
  rescue => e
    Rails.logger.debug log_text
    NewRelic::Agent.notice_error(e, {
        :custom_params => {
          :description => "Error in writing to sbrr.log, #{e.message}",
      }})
  end

end
