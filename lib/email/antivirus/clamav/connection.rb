require 'time'
require 'timeout'

# tcp_port and tcp_host value should be same as it is stored in /usr/local/etc/clamav/clamd.conf
# For example to intialize connection with diiferent credentials, conn = Clamav::Client.scan(tcp_port: 3310, tcp_host: '127.0.0.1', io: File.open("/Users/mukesh/Desktop/large_file.txt"))
module Email::Antivirus::Clamav
  class Connection
    class << self

      include Redis::RedisKeys
      include Redis::OthersRedis

      class MaxRetyLimitError < StandardError
      end

      CONNECTION_ERROR_TIMEOUT = 600
      MAX_SOCKET_ERROR_LIMIT = 10  
          
      attr_accessor :option, :clamav_scan, :permanent_connection

      def initialize_connection(option = {})
        begin 
          @@connection_error_count = 0 unless (defined? @@connection_error_count)
          @@error_time = nil unless (defined? @@error_time)
          @initialisation_error = false
          @option = option
          @tcp_host = option[:tcp_host] || ClamavConfig::TCP_HOST
          @tcp_port = option[:tcp_port] || ClamavConfig::TCP_PORT
          @unix_socket = option[:unix_socket]
          @timeout = option[:timeout] || 55
          @option[:size] ||= ClamavConfig::CONNECTION_POOL_SIZE
          @option[:clamav_client] = create_clamav_connection
          self.clamav_scan = @option[:clamav_scan] = Email::Antivirus::Clamav::Scan.new()
          self.permanent_connection = Email::Antivirus::Clamav::ConnectionsPool.new(@option)
          @@is_initialised = true
        rescue MaxRetyLimitError => e
          Rails.logger.error "CLAMAV :: Max Connection Retry limit reached. Scanning will start after #{@@error_time + connection_error_timeout}"
          @initialisation_error = true
        rescue => e
          Rails.logger.error "CLAMAV ::  #{e.class} Error while initialisation. Error count #{@@connection_error_count} : #{e.message} - #{e.backtrace}"
          increase_connection_error_count
        end
      end

      def create_clamav_connection
        clamav_connection = ClamAV::Client.new(default_connection) 
      end

      def default_connection
        socket = create_socket
        connection = ClamAV::Connection.new(
          socket: socket,
          wrapper: ::ClamAV::Wrappers::NewLineWrapper.new
        )
      end

      def create_socket
        if @@error_time && ((Time.now.utc - @@error_time) < connection_error_timeout)
          raise MaxRetyLimitError
        else
          Timeout.timeout(15) do
            if @tcp_host && @tcp_port
              @socket_connection = ::TCPSocket.new(@tcp_host, @tcp_port)
            else
              @socket_connection = ::UNIXSocket.new(@unix_socket || '/var/run/clamav/clamd.ctl')
            end
          end
        end
        @@connection_error_count = 0
        @@error_time = nil
        @socket_connection  
      end          
         
      def scan(args={})
        initialize_connection(args) unless ((defined? @@is_initialised) && @@is_initialised)
        return ["initialisation_error"] if @initialisation_error
        begin
           if clamav_scan.perm_stack.size >= @option[:size]
            response = temporary_scan(args)
           else
            response = permanent_connection.scan(args)
           end
        rescue  => e
          Rails.logger.error "CLAMAV :: #{e.class} Error occured while scaning : #{e.message} --  #{e.backtrace}"
          @@is_initialised = false
          response = temporary_scan(args)
        ensure
          parsed_response = parse_response response if response
          Rails.logger.info "CLAMAV :: Response : #{parsed_response}"
        end
        return parsed_response
      end 

      def temporary_scan args
        begin
          Rails.logger.info "CLAMAV :: Scanning by temporary connection perm_stack size : #{clamav_scan.perm_stack.size} "
          clamav_conn = create_clamav_connection
          response = clamav_scan.scan_io_stream(args,clamav_conn)
          Rails.logger.info "CLAMAV :: Scanning process completed by temporary connection "
        rescue => e
          Rails.logger.error "CLAMAV :: #{e.class} Error in Clamav Client : #{e.message} -- #{e.backtrace}"
        ensure
          close_temporary_clamav_conn clamav_conn
        end
        return response
      end

      def close_temporary_clamav_conn clamav_conn
        begin
          response = clamav_conn.execute(ClamAV::Commands::QuitCommand.new)
          Rails.logger.info "CLAMAV :: Temporary Clamav Connection has been shutdown properly" if response == false
        rescue => e
          Rails.logger.error "CLAMAV :: #{e.class} Error occured while closing Temporary Clamav Connection  : #{e.message} -- #{e.backtrace}"
        end
      end

      def parse_response response
        error_str = response.error_str
        file = response.file
        virus_name = response.virus_name
        if error_str
          message = "error"
        elsif file && virus_name
          message = "virus"
        elsif file
          message = "success"
        end
        return message, file, virus_name, error_str
      end
      
      def connection_error_timeout
        timeout = ( get_others_redis_key(CLAMAV_CONNECTION_ERROR_TIMEOUT) || CONNECTION_ERROR_TIMEOUT).to_i
      end

      def increase_connection_error_count
        @initialisation_error = true
        @@error_time = Time.now.utc if @@connection_error_count >= MAX_SOCKET_ERROR_LIMIT
        @@connection_error_count += 1
      end
    end
  end
end