require 'time'
require 'timeout'

module Email::Antivirus::Clamav
  class ConnectionHandler

    class ConnectionsPoolInitialisationError < StandardError
    end

    attr_accessor :initialisation_error, :pool_size, :timeout, :connection_pool
    
    MAX_SOCKET_ERROR_LIMIT = 10

    def initialize(args= {})
      self.pool_size = args[:pool_size] || ClamavConfig::CONNECTION_POOL_SIZE
      self.timeout   = args[:timeout] || ClamavConfig::CONNECTION_TIMEOUT
      self.initialisation_error = false
      Email::Antivirus::Clamav.check_connection
      create_connection_pool
    rescue Email::Antivirus::Clamav::MaxRetyLimitError => e
      log_info "Max Connection Retry limit reached. Scanning will start after #{get_next_retry_time + Email::Antivirus::Clamav.connection_error_timeout}"
      initialisation_error = true
    rescue ConnectionsPoolInitialisationError => e
    rescue => e
      log_info " #{e.class} while initialisation. Error count #{get_error_count + 1}. Next retry time #{get_next_retry_time}. : #{e.message} - #{e.backtrace}"
      increase_error_count
    end

    def create_connection_pool
      args = {:pool_size => pool_size, :timeout => timeout}
      self.connection_pool = Email::Antivirus::Clamav::ConnectionPoolFactory.get_connection_pool(args)
    rescue => e
      log_info "#{e.class} while creating connection_pool - #{e.message} - #{e.bactrace}"
      Email::Antivirus::Clamav::ConnectionPoolFactory.reset_connection_pool
      raise ConnectionsPoolInitialisationError
    end 
 
    def scan_for_virus(args={})
      args.merge!({:pool_size => pool_size, :timeout => timeout})
      return ["initialisation_error"] if initialisation_error
      response = Email::Antivirus::Clamav::VirusScanner.new(connection_pool).check(args)
    end

    private

    def increase_error_count
      error_count = get_error_count
      initialisation_error = true
      set_next_retry_time Time.now.utc if error_count >= MAX_SOCKET_ERROR_LIMIT
      set_error_count (error_count + 1)
    end

    def get_next_retry_time
      Email::Antivirus::Clamav.get_next_retry_time
    end

    def set_next_retry_time(val)
      Email::Antivirus::Clamav.set_next_retry_time val
    end
    
    def get_error_count
      Email::Antivirus::Clamav.get_error_count
    end

    def set_error_count(val)
      Email::Antivirus::Clamav.set_error_count val
    end

    def log_info(message)
      Rails.logger.info "CLAMAV :: #{message}"
    end
    
  end
end