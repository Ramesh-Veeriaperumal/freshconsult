module Channel
  class PortalsController < ::Ember::PortalsController
    include ChannelAuthentication

    skip_before_filter :check_privilege
    before_filter :channel_client_authentication

    def index
      super
    end
  end
end
