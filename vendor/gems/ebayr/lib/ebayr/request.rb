
module Ebayr
  class Request
    include Ebayr

    attr_reader :command

    def initialize(command, ecommerce_account_id, options = {})
      set_configs(ecommerce_account_id)
      @command = self.class.camelize(command.to_s)
      @uri = options.delete(:uri) || self.uri
      @uri = URI.parse(@uri) unless @uri.is_a? URI
      @site_id = ( @site_id || options.delete(:site_id) ).to_s
      @auth_token = @auth_token || options.delete(:auth_token)
      @compatability_level = (options.delete(:compatability_level) || self.compatability_level).to_s
      @http_timeout = (options.delete(:http_timeout) || 60).to_i
      @input = options.delete(:input) || options
      
    end
    
    def input_xml
      self.class.xml(@input)
    end

    def path
      @uri.path
    end

    # Gets the headers that will be sent with this request.
    def headers
      {
        'X-EBAY-API-COMPATIBILITY-LEVEL' => @compatability_level.to_s,
        'X-EBAY-API-DEV-NAME' => dev_id.to_s,
        'X-EBAY-API-APP-NAME' => app_id.to_s,
        'X-EBAY-API-CERT-NAME' => cert_id.to_s,
        'X-EBAY-API-CALL-NAME' => @command.to_s,
        'X-EBAY-API-SITEID' => @site_id.to_s,
        'Content-Type' => 'text/xml'
      }
    end

    # Gets the body of this request (which is XML)
    def body
      <<-XML
        <?xml version="1.0" encoding="utf-8"?>
        <#{@command}Request xmlns="urn:ebay:apis:eBLBaseComponents">
          #{construct_requester_credential}
          #{input_xml}
          <ErrorLanguage>#{Ecommerce::Ebay::Constants::EBAY_ERROR_LANGUAGE}</ErrorLanguage>
        </#{@command}Request>
      XML
    end

    # Makes a HTTP connection and sends the request, returning an
    # Ebayr::Response
    def send
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.read_timeout = @http_timeout

      if @uri.port == 443
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      post = Net::HTTP::Post.new(@uri.path, headers)
      post.body = body

      response = http.start { |http| http.request(post) }

      @response = Response.new(self, response)
    end

    def set_configs(ebay_account_id)
      unless ebay_account_id.blank?
        ebay_acc = Account.current.ebay_accounts.find_by_id(ebay_account_id)
        @auth_token = ebay_acc.configs[:auth_token]
        @expired = ebay_acc.reauth_required
        @site_id = ebay_acc.configs[:site_id]
      end
    end

    def to_s
      "#{@command}[#{@input}] <#{@uri}>"
    end

    # A very, very simple XML serializer.
    #
    #     Ebayr.xml("Hello!")       # => "Hello!"
    #     Ebayr.xml(:foo=>"Bar")  # => <foo>Bar</foo>
    #     Ebayr.xml(:foo=>["Bar","Baz"])  # => <foo>Bar</foo>
    def self.xml(*args)
      args.map do |structure|
        case structure
          when Hash then structure.map { |k, v| "<#{k.to_s}>#{xml(v)}</#{k.to_s}>" }.join
          when Array then structure.map { |v| xml(v) }.join
          else self.serialize_input(structure).to_s
        end
      end.join
    end

    # Prepares an argument for input to an eBay Trading API XML call.
    # * Times are converted to ISO 8601 format
    def self.serialize_input(input)
       case input
         when Time then input.to_time.utc.iso8601
         else input
      end
    end

    def construct_requester_credential
      unless @auth_token.blank? 
        "<RequesterCredentials>
          <eBayAuthToken>#{@auth_token}</eBayAuthToken>
        </RequesterCredentials>"
      end
    end

    # Converts a command like get_ebay_offical_time to GeteBayOfficialTime
    def self.camelize(string)
      string = string.to_s
      return string unless string == string.downcase
      string.split('_').map(&:capitalize).join.gsub('Ebay', 'eBay')
    end

    # Gets a HTTP connection for this request. If you pass in a block, it will
    # be run on that HTTP connection.
    def http(&block)
      http = Net::HTTP.new(@uri.host, @uri.port)
      if @uri.port == 443
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      return http.start(&block) if block_given?
      http
    end
  end
end
