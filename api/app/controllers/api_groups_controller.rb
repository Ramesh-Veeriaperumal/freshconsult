class ApiGroupsController < ApiApplicationController
  before_filter :prepare_agents, only: [:create, :update]
  before_filter :set_round_robin_enbled

  private

    def validate_params
      group_params = current_account.features_included?(:round_robin) ? GroupConstants::FIELDS : GroupConstants::FIELDS_WITHOUT_TICKET_ASSIGN
      params[cname].permit(*(group_params))
      group = ApiGroupValidation.new(params[cname], @item)
      render_errors group.errors, group.error_options unless group.valid?
    end

    def load_object
      @item = scoper.detect { |group| group.id == params[:id].to_i }
      unless @item
        head :not_found # Do we need to put message inside response body for 404?
      end
    end

    def scoper
      create? ? current_account.groups : current_account.groups_from_cache
    end

    def set_round_robin_enbled
      @round_robin_enabled = current_account.features_included? :round_robin
    end

    def initialize_agents
      @agents = Array.wrap params[cname][:user_ids] if params[cname].key?(:user_ids)
    end

    def sanitize_params
      params[cname][:unassigned_for] = GroupConstants::UNASSIGNED_FOR_MAP[params[cname][:unassigned_for]]
      ParamsHelper.assign_and_clean_params({ unassigned_for: :assign_time, auto_ticket_assign: :ticket_assign_type },
                                           params[cname])
    end

    def prepare_agents
      initialize_agents
      drop_existing_agents if update? && @agents
      build_agents
    end

    def build_agents
      @agents.each { |agent| @item.agent_groups.build(user_id: agent) } unless @agents.blank?
    end

    def drop_existing_agents
      if @agents.empty?
        @item.agent_groups.destroy_all
      else
        @item.agent_groups.where('user_id not in (?)', @agents).destroy_all
      end
      @agents -= @item.agent_groups.map(&:user_id)
    end

    def set_custom_errors(_item = @item)
      bad_agent_ids = @item.agent_groups.select { |x| x.errors.present? }.collect(&:user_id)
      @item.errors.add(:user_ids, 'list is invalid') if bad_agent_ids.present?
      @error_options = { remove: :'agent_groups.user', user_ids: { list: "#{bad_agent_ids.join(', ')}" } }
      @error_options
    end
end
