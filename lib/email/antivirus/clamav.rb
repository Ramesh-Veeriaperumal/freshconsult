require 'time'
require 'timeout'

module Email::Antivirus::Clamav
  
  class MaxRetyLimitError < StandardError
  end

  class << self
  include Redis::RedisKeys
  include Redis::OthersRedis

  CONNECTION_ERROR_TIMEOUT = 600
  @@next_retry_time = nil
  @@error_count = 0

  def client_connection
    @tcp_host = ClamavConfig::TCP_HOST 
    @tcp_port = ClamavConfig::TCP_PORT
    @socket_timeout = ClamavConfig::SOCKET_TIMEOUT
    Proc.new { ClamAV::Client.new(default_connection) }
  rescue => e
    puts "#{e.class} while creating clamav client connection. Error count #{@@error_count}"
    raise e
  end

  def default_connection
    socket = create_socket
    ClamAV::Connection.new(
      socket: socket,
      wrapper: ::ClamAV::Wrappers::NewLineWrapper.new
    )
  end

  def create_socket
    conn_timeout = connection_error_timeout
    if @@next_retry_time && ((Time.now.utc - @@next_retry_time) < conn_timeout)
      log_info "Max Retry limit reached. Connection will be retried after #{@@next_retry_time}"
      raise MaxRetyLimitError
    else
      Timeout.timeout(@socket_timeout) { @socket_connection = ::TCPSocket.new(@tcp_host, @tcp_port) }
    end
  end

  def scan_io_stream(io_stream,connection)
    clamav_response = connection.call.execute(ClamAV::Commands::InstreamCommand.new(io_stream))
    final_response = parse_response(clamav_response) if clamav_response 
  end
  
  def check_connection
    clamav_response =  client_connection.call.execute(ClamAV::Commands::PingCommand.new())
    if clamav_response == true
      log_info "Clamav client connected successfully during connection test"
      set_error_count 0
      set_next_retry_time nil
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

  def get_error_count
    @@error_count
  end

  def set_error_count(val)
    @@error_count = val
  end

  def get_next_retry_time
    @@next_retry_time
  end

  def set_next_retry_time(val)
    @@next_retry_time = val
  end

  def log_info(message)
    Rails.logger.info "CLAMAV :: #{message}"
  end

  end
end