module Ember
  class GroupsController < ::ApiGroupsController
    decorate_views
    def index
      super
      response.api_meta = { count: @items_count }
    end

    private

      def decorator_options
        super({ agent_groups_ids: group_agents_mappings })
      end

      def group_agents_mappings
        agent_groups_ids = Hash.new { |hash, key| hash[key] = [] }
        agents_groups = current_account.agent_groups_from_cache
        agents_groups.each do |ag|
          agent_groups_ids[ag.group_id].push(ag.user_id)
        end
        agent_groups_ids
      end
  end
end
