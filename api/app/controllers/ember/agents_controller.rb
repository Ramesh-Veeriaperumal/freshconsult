module Ember
  class AgentsController < ApiAgentsController
    include Helpdesk::DashboardHelper
    include AgentAvailabilityHelper
    include AgentContactConcern
    include HelperConcern

    decorate_views(decorate_object: [:show, :achievements], decorate_objects: [:index, :create_multiple])

    def constants_class
      :AgentConstants.to_s.freeze
    end

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

    def create_multiple
      @errors = []
      build_default_required_params
      return unless validate_params
      build_objects
      validate_items_to_create
      create_objects
      render_partial_success(@succeeded_items, @errors, 'ember/agents/create_multiple')
      # response.api_meta = { count: @items.count }
    end

    private

      def build_default_required_params
        params[cname][:agents].each do |agent|
          agent[:name] ||= agent[:email].split('@')[0]
        end
      end

      def validate_params
        params[cname][:agents].each do |agent_params|
          return false unless validate_request(nil, agent_params, nil)
        end
        true
      end

      def build_objects
        @items = []
        agent_role_id = current_account.roles.agent.first.id
        params[cname][:agents].each do |agent_params|
          user = current_account.users.build(agent_params)
          user.helpdesk_agent = true
          user.role_ids = [agent_role_id] unless agent_params[:role_ids]
          @items << user
        end
      end

      def validate_items_to_create
        @validation_failed_items = []
        @items.each do |item|
          unless validate_item_delegator(item)
            @validation_failed_items << item
            @errors.push(delegation_error_hash(item))
          end
        end
      end

      def validate_item_delegator(item)
        @agent_delegator = AgentDelegator.new(params[cname]['agents'].first.slice(:role_ids, :group_ids))
        @agent_delegator.valid?
      end

      def delegation_error_hash(item)
        ret_hash = {}
        ret_hash[:email] = item.email
        ret_hash[:validation_errors] = @agent_delegator
        ret_hash
      end

      def create_objects
        create_failed_items = []
        @succeeded_items = []
        items_to_create.each do |item|
          if create_user_and_make_agent(item)
            @succeeded_items << AgentDecorator.new(item.agent, group_mapping_ids: []).to_hash
          else
            @errors.push(agent_creation_error(item))
            create_failed_items << item
          end
        end
        create_failed_items
      end

      def items_to_create
        @items - @validation_failed_items
      end

      def create_user_and_make_agent(item)
        item.signup!({}, nil, !current_account.freshid_enabled?, false) && item.create_agent
      end

      def agent_creation_error(item)
        ret_hash = { email: item.email, errors: item.errors, error_options: {} }
      end

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
