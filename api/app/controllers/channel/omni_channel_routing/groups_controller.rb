module Channel::OmniChannelRouting
  class GroupsController < ::ApiGroupsController
    include ChannelAuthentication
    skip_before_filter :check_privilege
    before_filter :channel_client_authentication

    def index
      load_objects
    end

    def self.decorator_name
      ::GroupDecorator
    end

    private

      def scoper
        current_account.groups_from_cache
      end

      def load_objects(items = scoper)
        items.sort_by { |x| x.name.downcase }
        @items_count = items.count if private_api?
        @items = items
      end
  end
end
