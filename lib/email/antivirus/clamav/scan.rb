module Email::Antivirus::Clamav
  class Scan

    class ConnectionError < StandardError
    end

    attr_accessor :perm_stack

    def initialize timeout = 50.0
      @timeout = timeout
      self.perm_stack = []
    end

    def permanent_scan connection_pool, option
      timeout = option[:timeout] || @timeout
      connection_pool.with(:timeout => timeout) do |perm_conn|
        perm_stack.push(perm_conn)
        @response = scan_io_stream(option,perm_conn)
        perm_stack.pop
      end
      return @response
    end

    def scan_io_stream(option,clamav_conn)
      if option[:io]
        response = clamav_conn.execute(ClamAV::Commands::InstreamCommand.new(option[:io]))
      elsif option[:file]
        response = clamav_conn.execute(ClamAV::Commands::InstreamCommand.new(File.open(option[:file])))
      else
        Rails.logger.info "CLAMAV :: Provide either I/O stream or file path for scanning"
      end
      return response
    end
  end
end