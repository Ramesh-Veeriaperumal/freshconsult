module ChannelIntegrations::Utils
  module ActionParser
    def current_account
      @current_account ||= Account.current
    end

    # Default format for the Success reply from the Channel framework.
    def default_success_format
      {
        data: {},
        status_code: 200,
        reply_status: 'success'
      }
    end

    # Default format for the Failure reply from the Channel framework.
    def default_error_format
      {
        data: {},
        status_code: 400,
        reply_status: 'error'
      }
    end
  end
end
