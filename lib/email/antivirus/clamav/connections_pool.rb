require 'time'
require 'timeout'

module Email::Antivirus::Clamav
  class ConnectionsPool

    class ConnectionsPoolError < StandardError
    end
    
    attr_accessor :connection_pool
    def initialize(args = {})
      Rails.logger.info "CLAMAV :: Initializing connection pool"
      @args = args
      @args[:clamav_client] ||= ClamAV::Client.new(default_connection) 
      @clamav_scan = args[:clamav_scan]
      resp = check_connection
      create_connection unless resp
      connection_pool
    end

    def create_connection
      self.connection_pool = ConnectionPool.new(:size => @size, :timeout => @timeout) {  @args[:clamav_client]  } 
      Rails.logger.info "CLAMAV :: Created a new Connection for connection pool"
    end
    
    def scan(args={})
      begin
        Rails.logger.info "CLAMAV :: Scanning by permanent connection perm_stack size : #{@clamav_scan.perm_stack.size} "
        response = @clamav_scan.permanent_scan(connection_pool, args)
        Rails.logger.info "CLAMAV :: Scanning process completed by permanent connection " 
      rescue => e
        Rails.logger.error "CLAMAV ::  #{e.class} Error while scanning through connection pool : -- #{e.message} -- #{e.backtrace}"
        response = retry_scan args
      end
      response
    end 

    def retry_scan args
      begin
        Rails.logger.info "CLAMAV :: Restarting the permanent connection for clamav client"
        shutdown
        create_connection
        response = @clamav_scan.permanent_scan(connection_pool, args)
        Rails.logger.info "CLAMAV :: Scanning process completed by permanent connection "
      rescue => e
        Rails.logger.error "CLAMAV :: #{e.class} Error during restart of connection pool -- #{e.message} -- #{e.backtrace}"
        raise ConnectionsPoolError
      end
      response
    end  

    def shutdown(timeout = 5)
      connection_pool.with(:timeout => timeout) do |conn|
        response = conn.execute(ClamAV::Commands::QuitCommand.new)
        Rails.logger.info "CLAMAV :: Connection Pool has been shutdown properly" if response == false
      end
    end

    def check_connection(timeout = 2)
      return false unless connection_pool
      connection_pool.with(:timeout => timeout) do |conn|
        response = conn.execute(ClamAV::Commands::PingCommand.new)
      end
    end
  end
end