module IntegrationServices
  module Errors
    
    # Public: Raises a configuration error inside a service, and halts further
    # processing.
    #
    # Raises a Service;:ConfigurationError.
    def raise_config_error(msg = "Invalid configuration")
      raise ConfigurationError, msg
    end
    
    # Raised when an unexpected error occurs during service hook execution.
    class Error < StandardError
      attr_reader :original_exception
      def initialize(message, original_exception=nil)
        original_exception = message if message.kind_of?(Exception)
        @original_exception = original_exception
        super(message)
      end
    end

    # Raised when trying to access functionalities without having the feature enabled
    class AccessDeniedError < Error
    end

    # Raised when a service hook fails due to bad configuration. Services that
    # fail with this exception may be automatically disabled.
    class ConfigurationError < Error
    end
    
    # Raised when a service hook fails due to an issue communicating with the 
    # remote system.
    class RemoteError < Error
      attr_reader :status_code
      def initialize(message, status_code = nil)
        @status_code = status_code
        super(message)
      end
    end
    
    # Raised when an invalid webhook URL is used.
    class InvalidUrlError < Error
    end

    class TimeoutError < Timeout::Error
    end
  end
end
