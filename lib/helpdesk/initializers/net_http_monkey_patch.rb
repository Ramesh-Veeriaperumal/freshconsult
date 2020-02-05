# Monkey patching the on_connect hook method in Net::HTTP to validate
# the address to be connected after resolving, but before making any data transfers
# this should prevent DNS rebinding SSRF attack
require 'net/protocol'
require 'uri'

module Net
  class HTTP < Protocol
    PROHIBITED_ADDRESS = [
      '0.0.0.0/8',
      '255.255.255.255/32',
      '127.0.0.0/8',
      '10.0.0.0/8',
      '169.254.0.0/16',
      '172.16.0.0/12',
      '192.168.0.0/16',
      '224.0.0.0/4',
      'fc00::/7',
      'fe80::/10',
      '::1'
    ].collect do |a|
      IPAddr.new(a)
    end

    attr_accessor :verify_blacklist

    private

      alias on_connect_without_validation on_connect

      def on_connect
        remote_ip = @socket.io.peeraddr.last
        if verify_blacklist && remote_ip
          PROHIBITED_ADDRESS.each do |addr|
            if addr === remote_ip
              @socket.close
              raise ArgumentError, "#{@address} is not allowed"
            end
          end
        end
        on_connect_without_validation
      end
  end
end

module HTTParty
  class ConnectionAdapter
    alias connection_without_blacklist_option connection

    def connection
      http = connection_without_blacklist_option
      http.verify_blacklist = options[:verify_blacklist]
      http
    end
  end
end
