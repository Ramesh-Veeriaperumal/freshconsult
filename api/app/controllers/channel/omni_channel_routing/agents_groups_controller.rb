module Channel::OmniChannelRouting
  class AgentsGroupsController < Ember::Bootstrap::AgentsGroupsController
    include ChannelAuthentication
    skip_before_filter :check_privilege
    before_filter :channel_client_authentication

    def index
      agents_groups = Account.current.agent_groups_from_cache.map do |x|
        { agent_id: x.user_id, group_id: x.group_id }
      end
      @items = { agents_groups: agents_groups }
    end
  end
end
