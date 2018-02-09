module ChannelIntegrations::Utils
	 module ActionParser
    def current_account
      @current_account ||= Account.current
    end
  end
end