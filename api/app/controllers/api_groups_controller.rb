class ApiGroupsController < ApiApplicationController
  before_filter :prepare_agents, only: [:create, :update]

  def create
    group_delegator = GroupDelegator.new(@item)
    if !group_delegator.valid?
      render_errors(group_delegator.errors, group_delegator.error_options)
    elsif @item.save
      render_201_with_location(item_id: @item.id)
    else
      render_errors(@item.errors)
    end
  end

  def update
    @item.assign_attributes(params[cname])
    group_delegator = GroupDelegator.new(@item)
    if !group_delegator.valid?
      render_errors(group_delegator.errors, group_delegator.error_options)
    elsif !@item.update_attributes(params[cname])
      render_errors(@item.errors)
    end
  end

  private

    def validate_params
      group_params = Account.current.features?(:round_robin) ? GroupConstants::FIELDS : GroupConstants::FIELDS_WITHOUT_TICKET_ASSIGN
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

    def initialize_agents
      prepare_array_fields [:agent_ids]
      @agent_ids = params[cname][:agent_ids]
    end

    def load_objects
      super(scoper.sort_by { |x| x.name.downcase })
    end

    def sanitize_params
      params[cname][:unassigned_for] = GroupConstants::UNASSIGNED_FOR_MAP[params[cname][:unassigned_for]]
      ParamsHelper.assign_and_clean_params({ unassigned_for: :assign_time, auto_ticket_assign: :ticket_assign_type },
                                           params[cname])
    end

    def prepare_agents
      initialize_agents
      drop_existing_agents if update? && @agent_ids
      build_agents
    end

    def build_agents
      @agent_ids.each { |agent| @item.agent_groups.build(user_id: agent, account: Account.current, group: @item) } unless @agent_ids.blank?
    end

    def drop_existing_agents
      agent_groups = @item.agent_groups
      if @agent_ids.empty?
        agent_groups.destroy_all
      else
        revised_agent_groups = agent_groups.select { |ag| @agent_ids.exclude?(ag.user_id) }.map(&:destroy)
        agent_groups -= revised_agent_groups
        @agent_ids -= agent_groups.map(&:user_id)
        @item.agent_groups = agent_groups if @agent_ids.empty? || agent_groups.empty?
      end
    end
end
