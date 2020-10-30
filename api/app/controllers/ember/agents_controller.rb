module Ember
  class AgentsController < ApiAgentsController
    include Helpdesk::DashboardHelper
    include AgentAvailabilityHelper
    include AgentContactConcern
    include HelperConcern
    decorate_views(decorate_object: [:show, :achievements], decorate_objects: [:index, :create_multiple])

    def index
      super
      if availability_count?
        response.api_meta = { agents_available: agents_availability_count }
      else
        external_agents_availability if agent_availability_details?
        response.api_meta = { count: @items_count } unless privilege_filter?
      end
    end

    def update
      mark_avatar_for_destroy
      super
    end

    private

      def validate_params
        validate_body_params(@item)
      end

      def constants_class
        'Ember::AgentConstants'.freeze
      end

      def agent_delegator_params
        agent_params = {}
        agent_params[:attachment_ids] = Array.wrap(params[cname][:avatar_id].to_i) if params[cname][:avatar_id].present?
        agent_params
      end

      def mark_avatar_for_destroy
        user_avatar = @item.user.avatar
        avatar_id = user_avatar.id if params[cname].key?('avatar_id') && user_avatar
        if avatar_id.present? && avatar_id != params[cname][:avatar_id]
          params[cname][:user_attributes][:avatar_attributes] = { id: avatar_id, _destroy: 1 }
          @avatar_changes = :destroy
        end
      end

      def agent_delegator_klass
        'AgentDelegator'.constantize
      end

      def load_objects
        if params[:only] == 'available_count'
          @items = []
        elsif agent_availability_details? && !current_user.privilege?(:admin_tasks)
          super(supervisor_scoper_agent_availability)
        elsif privilege_filter?
          @privilege_filter = true
          @items = privilege_scoper
        else
          super
          if @only_omni_channel_availability
            @items_count = @parsed_omni_agents_count || 0
          elsif User.current.privilege?(:manage_users)
            @day_pass_used_count = day_pass_used_count(@items.select { |i| i.occasional == true }.map(&:user_id))
          end
        end
      end

      def decorator_options
        super({ agent_groups: Account.current.agent_groups_from_cache, include: params[:include] })
      end

      def sanitize_params
        agent_channels = ::AgentConstants::AGENT_CHANNELS
        if params[cname][agent_channels[:ticket_assignment]]
          params[cname][:available] = params[cname][agent_channels[:ticket_assignment]]['available']
          params[cname].except!(*[agent_channels[:ticket_assignment]])
        end
        super
      end

      def scoper
        load_from_cache? ? current_account.agents_details_ar_from_cache : current_account.agents.preload(preload_options)
      end

      def load_from_cache?
        index? && !User.current.privilege?(:manage_users) && !agent_availability_details? && @agent_filter.conditions.empty?
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

      def privilege_filter?
        params[:only] == 'with_privilege'
      end

      def agent_availability_details?
        params[:only] == 'available' && current_user.privilege?(:manage_availability)
      end

      def privilege_scoper
        privilege = params[:privilege].to_sym
        current_account.agents_details_from_cache.select { |x| x.privilege?(privilege) }
      end

      def supervisor_scoper_agent_availability
        agent_groups = current_account.agent_groups_from_cache
        current_user_id = current_user.id
        group_ids = agent_groups.select { |ag| (ag.user_id == current_user_id) }.map(&:group_id)
        return [] if group_ids.empty?
        agent_ids =  agent_groups.select { |ag| group_ids.include?(ag.group_id) }.map(&:user_id).uniq
        scoper.where(user_id: agent_ids)
      end

      def day_pass_used_count(user_ids)
        day_passes_map = current_account.day_pass_usages.where(user_id: user_ids).group(:user_id).count(:id)
        users_with_no_day_passes = (user_ids - day_passes_map.keys).map { |user_id| [user_id, 0] }.to_h
        day_passes_map.merge!(users_with_no_day_passes)
      end
  end
end
