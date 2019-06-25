class FreddyLogger
  class << self
    def log_path
      Rails.root.join('log', 'freddy.log')
    end

    def logger
      @logger ||= Logger.new(log_path)
    end

    def log(content)
      logger.debug content
    rescue StandardError => e
      Rails.logger.error "Exception while writing to bot.log :: content=#{content.inspect} :: exception=#{e.inspect} :: backtrace=#{e.bactrace[0..10].inspect}"
    end
  end
end
