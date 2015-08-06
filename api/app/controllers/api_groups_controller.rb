class ApiGroupsController < ApiApplicationController
  before_filter :preparing_agents, only: [:create, :update]
  before_filter :set_round_robin_enbled

  def create
    group_delegator = GroupDelegator.new(@item)
    if !group_delegator.valid?
      render_error(group_delegator.errors, group_delegator.error_options)
    elsif @item.save
      render_201_with_location(item_id: @item.id)
    else
      set_custom_errors
      render_error(@item.errors)
    end
  end

  def update
    @item.assign_attributes(params[cname])
    @item.agent_groups = @item.agent_groups
    group_delegator = GroupDelegator.new(@item)
    if !group_delegator.valid?
      set_custom_errors(group_delegator)
      render_error(group_delegator.errors, group_delegator.error_options)
    elsif !@item.update_attributes(params[cname])
      set_custom_errors
      render_error(@item.errors)
    end
  end

  private

    def validate_params
      group_params = current_account.features_included?(:round_robin) ? GroupConstants::GROUP_FIELDS : GroupConstants::GROUP_FIELDS_WITHOUT_TICKET_ASSIGN
      params[cname].permit(*(group_params))
      group = ApiGroupValidation.new(params[cname], @item)
      render_error group.errors, group.error_options unless group.valid?
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
      @agents = Array.wrap params[cname][:agent_ids] if params[cname].key?(:agent_ids)
    end

    def manipulate_params
      params[cname][:unassigned_for] = GroupConstants::UNASSIGNED_FOR_MAP[params[cname][:unassigned_for]]
      ParamsHelper.assign_and_clean_params({ unassigned_for: :assign_time, auto_ticket_assign: :ticket_assign_type },
                                           params[cname])
    end

    def preparing_agents
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
end
