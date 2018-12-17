module Channel::OmniChannelRouting
  class AgentsController < ::ApiAgentsController
    include ChannelAuthentication
    skip_before_filter :check_privilege
    before_filter :channel_client_authentication

    def index
      load_objects
    end

    def load_objects(items = scoper)
      items.sort_by { |x| x.name.downcase }
      @items_count = items.count if private_api?
      @items = items
    end

    def scoper
      current_account.agents.preload(:user)
    end
  end
end
