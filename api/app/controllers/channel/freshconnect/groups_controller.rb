module Channel::Freshconnect
  class GroupsController < ::ApiGroupsController
    include ChannelAuthentication

    skip_before_filter :check_privilege
    before_filter :channel_client_authentication

    SLAVE_ACTIONS = %w[index].freeze

    def index
      @items = scoper
    end

    def self.decorator_name
      ::GroupDecorator
    end

    private

      def scoper
        current_account.groups_from_cache
      end
  end
end
