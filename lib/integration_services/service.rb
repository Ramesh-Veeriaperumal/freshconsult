module IntegrationServices
  class Service
    include Networking
    include Errors

    # Public: Gets the unique payload data for this Service instance.
    #
    # Returns a Hash.
    attr_reader :payload

    # Public: Gets the identifier for the Service's event.
    #
    # Returns a Symbol.
    attr_reader :event

    # Public: Gets response web meta data like content_type, status, x-headers..etc
    #
    # Returns a Hash.
    attr_reader :web_meta


    attr_reader :event_method

    # Public: Gets the configuration data for this Service instance.
    #
    # Returns a Hash.
    attr_reader :configs

    # Public: Gets the logger instance.
    #
    # Returns a Logger.
    attr_reader :logger

    #Public: Gets the user agent
    #
    # Returns a string
    attr_reader :user_agent


    # Public: The meta configuration for the Service instance.
    #
    # Returns a Hash.
    attr_reader :meta_data

    def initialize(app, payload = nil, meta_data = {})
      @installed_app = app
      @user_agent = meta_data.delete(:user_agent) || "Freshdesk"
      @meta_data = meta_data
      @configs = app.configs[:inputs]
      @payload = payload
      @logger = Rails.logger
      @web_meta = {:content_type => :json, :status => :ok}
    end

    def self.default_http_options
      @@default_http_options ||= {
        :request => {:timeout => 10, :open_timeout => 5},
        :ssl => {:verify => false, :verify_depth => 5},
        :headers => {}
      }
    end

    # Returns the list of events the service responds to.
    def self.responds_to_events
      self.instance_methods.collect do |method|
        method =~ /receive_(.+)/
        $1
      end.compact.collect {|e| e.to_sym }
    end

    # Returns true if the service responds to the specified event.
    def self.responds_to_event(event)
      self.responds_to_events.include?(event.to_sym)
    end

    # Returns a list of the services.
    def self.service_classes
      return @service_classes if @service_classes
      subclasses = {}
      ObjectSpace.each_object(Module) {|m| subclasses[m.title.downcase] =  m if m.ancestors.include?(Service) && m != Service}
      @service_classes = subclasses
    end

    def self.get_service_class service_name
      service_classes[service_name.downcase]
    end

    def respond_to_event?
      !@event_method.nil?
    end

    def receive(event, timeout = nil)
      @event = event.to_sym
      @event_method = ["receive_#{event}", "receive_event"].detect do |method|
        respond_to?(method)
      end

      unless respond_to_event?
        logger.info("#{self.class.title} ignoring event :#{@event}")
        return
      end
      logger.info("Sending :#{@event} using #{self.class.title}")
      timeout_sec = (timeout || 50).to_i
      Timeout.timeout(timeout_sec, TimeoutError) do
        send(event_method)
      end
    rescue Service::ConfigurationError, Errno::EHOSTUNREACH, Errno::ECONNRESET,
      SocketError, Net::ProtocolError, Faraday::Error::ConnectionFailed => err
      if !err.is_a?(Service::Error)
        err = ConfigurationError.new(err)
      end
      raise err
    end

    def receive_integrated_resource
      integrated_resource = @installed_app.integrated_resources.where(:local_integratable_id => @payload[:ticket_id], 
        :local_integratable_type => "Helpdesk::Ticket").select([:id, :local_integratable_id, :remote_integratable_id]).first
      integrated_resource.present? ? integrated_resource.attributes : {}
    end

    def update_configs(options = [{}])
      options.each do |opt|
        @installed_app.configs[:inputs][opt[:key]] = opt[:value]
        @configs[opt[:key]] = opt[:value]
      end
      @installed_app.save!
    end

    class << self
      # The official title of this Service.
      def title
        raise NotImplementedError
      end
    end
  end
end
Dir["#{Rails.root}/lib/integration_services/services/**/*.rb"].each { |f| require_dependency(f) }
