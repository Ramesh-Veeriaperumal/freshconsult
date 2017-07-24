module Ember
  class AgentsController < ApiAgentsController
    include Helpdesk::DashboardHelper
    include AgentAvailabilityHelper
    include HelperConcern

    decorate_views(decorate_object: [:show, :me, :achievements], decorate_objects: [:index])

    def index
      super
      if availability_count?
        response.api_meta = { agents_available: agents_availability_count }
      else
        external_agents_availability if agent_availability_details?
        response.api_meta = { count: @items_count }
      end
    end

    def update
      super
    end

    private

      def load_objects
        if params[:only] == 'available_count'
          @items = []
        elsif agent_availability_details? && !current_user.privilege?(:admin_tasks)
          super(supervisor_scoper_agent_availability)
        else
          super
        end
      end

      def decorator_options
        super({ agent_groups: Account.current.agent_groups_from_cache })
      end

      def sanitize_params
        agent_channels = AgentConstants::AGENT_CHANNELS
        if params[cname][agent_channels[:ticket_assignment]]
          params[cname][:available] = params[cname][agent_channels[:ticket_assignment]]['available']
          params[cname].except!(*[agent_channels[:ticket_assignment]])
        end
        super
      end

      def scoper
        load_from_cache ? current_account.agents_details_from_cache : current_account.agents.preload(preload_options)
      end

      def load_from_cache
        index? && !User.current.privilege?(:manage_users) && !agent_availability_details?
      end

      def achievements?
        @achievements ||= current_action?('achievements')
      end

      def preload_options
        achievements? ? [] : [user: [:avatar, :user_roles], agent_groups: []]
      end

      def availability_count?
        params[:only] == 'available_count'
      end

      def agent_availability_details?
        params[:only] == 'available' && current_user.privilege?(:manage_availability)
      end

      def supervisor_scoper_agent_availability
        agent_groups = current_account.agent_groups_from_cache
        current_user_id = current_user.id
        group_ids = agent_groups.select { |ag| (ag.user_id == current_user_id) }.map(&:group_id)
        return [] if group_ids.empty?
        agent_ids =  agent_groups.select { |ag| group_ids.include?(ag.group_id) }.map(&:user_id).uniq
        scoper.where(user_id: agent_ids)
      end
  end
end
