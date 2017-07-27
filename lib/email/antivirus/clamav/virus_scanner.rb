require 'time'
require 'timeout'

module Email::Antivirus::Clamav
  class VirusScanner

    class ConnectionsPoolError < StandardError
    end
    
    attr_accessor :connection_pool

    def initialize(connection_pool)
      self.connection_pool = connection_pool
    end

    def check(args)
      begin
        if (connection_pool.present? && connection_available?)
          response = permanent_scan(args)
        else
          response = temporary_scan(args)
        end
      rescue ConnectionsPoolError => e
        Email::Antivirus::Clamav::ConnectionPoolFactory.reset_connection_pool
        args[:io].rewind 
        response = temporary_scan(args)
      rescue  => e
        log_info "#{e.class} occured while scaning : #{e.message} --  #{e.backtrace}"
        response = ["error", nil, nil, "#{e.message}"]
      end
      args[:io].rewind
      log_info "Parsed response : #{response.join(", ")}"
      response
    end

    def permanent_scan(args)
      begin
        Timeout.timeout(args[:timeout]) do
          log_info "Scanning through permanent connection. Available permanent connections : #{connection_pool_size}"
          @clamav_connection = connection_pool.checkout(args)
          @response = Email::Antivirus::Clamav.scan_io_stream(args[:io], @clamav_connection)
          log_info "Permanent scan response : #{@response}"
          if @response[0] == "error"
            connection_pool.close_connection(@clamav_connection)
          else
            connection_pool.checkin
          end
        end
      rescue => e
        log_info "#{e.class} while scanning through connection pool : -- #{e.message} -- #{e.backtrace}"
        connection_pool.close_connection(@clamav_connection)
        raise ConnectionsPoolError
      end
      @response
    end 

    def temporary_scan(args)
      begin
        Timeout.timeout(args[:timeout]) do
          log_info "Scanning through temporary connection. Available permanent connections : #{connection_pool_size}" # "Scanning by temporary connection perm_stack size : #{clamav_scan.perm_stack.size} "
          @temporary_connection = Email::Antivirus::Clamav.client_connection
          @response = Email::Antivirus::Clamav.scan_io_stream(args[:io], @temporary_connection)
          log_info "Temporary scan response : #{@response}"
          sleep(args[:sleep_seconds1]) if args[:sleep_seconds1]
        end
      rescue => e
        log_info "#{e.class} while scanning through temporary connection : #{e.message} -- #{e.backtrace}"
        @response = ["error", nil, nil, "TemporaryScanError #{e.message}"] 
      end
      close_temporary_clamav_conn @temporary_connection
      @response
    end

    private

    def close_temporary_clamav_conn clamav_conn
      begin
        response = clamav_conn.call.execute(ClamAV::Commands::QuitCommand.new)
        log_info "Temporary Clamav Connection has been shutdown properly" if response == false 
      rescue => e
        log_info "#{e.class} Error while closing Temporary Connection : #{e.message} -- #{e.backtrace}"
      end  
    end

    #returns any connection is available in connection pool
    def connection_available?
      !connection_pool.is_full?
    end

    def connection_pool_size
      return "undefined" unless connection_pool.present?
      connection_pool.available_connection_length
    end

    def log_info(message)
      Rails.logger.info "CLAMAV :: #{message}"
    end
  end
end