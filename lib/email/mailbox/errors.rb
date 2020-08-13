module Email::Mailbox::Errors
  class MissingRedis < RuntimeError
    attr_reader :url_params_string
    def initialize(msg = 'Missing redis key in callback')
      @url_params_string = 'error=500'
      super(msg)
    end
  end
  
  class AuthenticateFailure < RuntimeError
    attr_reader :url_params_string
    def initialize(msg = 'Authenticate failure')
      @url_params_string = 'error=401'
      super(msg)
    end
  end
end
