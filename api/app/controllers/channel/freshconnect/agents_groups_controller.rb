module Channel::Freshconnect
  class AgentsGroupsController < Ember::Bootstrap::AgentsGroupsController
    include ChannelAuthentication

    skip_before_filter :check_privilege
    before_filter :channel_client_authentication

    SLAVE_ACTIONS = %w[index].freeze

    def index; end
  end
end
