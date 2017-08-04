require 'time'
require 'timeout'

module Email::Antivirus::Clamav
  class ConnectionPoolFactory
        
    DEFAULT_POOL_SIZE = 5
    DEFAULT_CONNECTION_TIMEOUT = 60
    @@clamav_connection_pool = nil
    
    #helps in a maintaining a singleton connection pool object
    def self.get_connection_pool(args = {})
      pool_size = args[:pool_size] || DEFAULT_POOL_SIZE
      timeout = args[:timeout] || DEFAULT_CONNECTION_TIMEOUT
      if @@clamav_connection_pool.blank?
        @@clamav_connection_pool = ConnectionPool.new(:size => pool_size, :timeout => timeout) { Email::Antivirus::Clamav.client_connection } 
        log_info "Connection Pool initialized with size : #{pool_size} , timeout : #{timeout}"
      end
      return @@clamav_connection_pool
    end

    def self.reset_connection_pool
      log_info "Reset ConnectionPool"
      @@clamav_connection_pool = nil
    end

    def self.log_info message
      Rails.logger.info "CLAMAV :: #{message}"
    end
    
  end
end