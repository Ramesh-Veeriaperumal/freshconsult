module IntegrationServices
  class GenericResource

    include Networking
    include Errors

    attr_reader :logger
    attr_reader :user_agent

    def initialize(service)
      @service = service
      @logger = service.logger
      @user_agent = service.user_agent
    end

    def parse(body)
      if body.nil? or body.length < 2
        {}
      else
        JSON.parse(body)
      end
    end

    def parse_xml(body)
      if body.nil? or body.length < 2
        {}
      else
        Nokogiri::XML(body)
      end
    end

    def prepare_request
    end

    def self.default_http_options
      @@default_http_options ||= {
        :request => {:timeout => 100, :open_timeout => 50},
        :ssl => {:verify => false, :verify_depth => 5},
        :headers => {}
      }
    end
  end
end
