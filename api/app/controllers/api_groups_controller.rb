class ApiGroupsController < ApiApplicationController
  wrap_parameters :api_group, exclude: [], format: [:json]
  before_filter :initialize_agents, only: [:create, :update]
  before_filter :drop_existing_agents, only: [:update], if: -> { @agents }
  before_filter :build_agents, only: [:create, :update]

  private

    def validate_params
      group_params = ApiConstants::GROUP_FIELDS.dup
      group_params.delete('auto_ticket_assign') unless current_account.features_included?(:round_robin)
      params[cname].permit(*(group_params))
      group = ApiGroupValidation.new(params[cname], @item)
      unless group.valid?
        if group.error_options.blank?
          render_error group.errors
        else
          render_custom_errors(group, group.error_options)
        end
      end
    end

    def scoper
      current_account.groups
    end

    def initialize_agents
      @agents = Array.wrap params[cname][:agents] if params[cname].key?(:agents)
    end

    def manipulate_params
      params[cname][:unassigned_for] = ApiConstants::UNASSIGNED_FOR_MAP[params[cname][:unassigned_for]]
      assign_and_clean_params(unassigned_for: :assign_time, auto_ticket_assign: :ticket_assign_type)
    end

    def build_agents
      @agents.each { |agent| @api_group.agent_groups.build(user_id: agent) } unless @agents.blank?
    end

    def drop_existing_agents
      if @agents.blank?
        @api_group.agent_groups.destroy_all
      else
        @api_group.agent_groups.where('user_id not in (?)', @agents).destroy_all
      end
      @agents -= @api_group.agent_groups.map(&:user_id)
    end

    def set_custom_errors
      bad_agent_ids = @item.agent_groups.select { |x| x.errors.present? }.collect(&:user_id)
      @item.errors.add('agents', 'list is invalid') if bad_agent_ids.present?
      @error_options = { remove: :"agent_groups.user", meta: "#{bad_agent_ids.join(', ')}" }
    end
end
