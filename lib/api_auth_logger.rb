class ApiAuthLogger
  class << self
    def log_path
      Rails.root.join('log', 'api_auth.log')
    end

    def logger
      @api_auth_logger ||= Logger.new(log_path)
    end

    def log(content)
      logger.debug content
    rescue StandardError => e
      Rails.logger.error "Exception while writing to api_auth.log :: content=#{content.inspect} :: exception=#{e.inspect} :: backtrace=#{e.bactrace}"
    end
  end
end
