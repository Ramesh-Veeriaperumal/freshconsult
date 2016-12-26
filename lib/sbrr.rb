module SBRR

  def self.log_path
    "#{Rails.root}/log/sbrr.log"
  end

  def self.logger
    @@sbrr_logger ||= Logger.new(log_path)
  end

  def self.log text
  	logger.debug "\n#{"%.5f" % Time.now.to_f}  #{text}" if Thread.current[:sbrr_log]
  end

end