class ApiGroupsController < ApiApplicationController
  include GroupConstants
  decorate_views
  before_filter :prepare_agents, only: [:create, :update]

  def create
    group_delegator = GroupDelegator.new(@item)
    if !group_delegator.valid?
      render_errors(group_delegator.errors, group_delegator.error_options)
    elsif @item.save
      render_success_response
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

    def validate_filter_params
      params.permit(*INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      @group_filter = GroupFilterValidation.new(params)
      render_errors(@group_filter.errors, @group_filter.error_options) unless @group_filter.valid?
    end

    def validate_params
      group_params = if update?
      current_account.features?(:round_robin) ? UPDATE_FIELDS : UPDATE_FIELDS_WITHOUT_TICKET_ASSIGN
      else
        current_account.features?(:round_robin) ? FIELDS : FIELDS_WITHOUT_TICKET_ASSIGN
      end
      params[cname].permit(*group_params)
      group = ApiGroupValidation.new(params[cname], @item)
      if create?
        render_errors group.errors, group.error_options unless group.valid?(:create)
      else
        render_errors group.errors, group.error_options unless group.valid?
      end
    end

    def load_object
      @item = current_account.groups.find_by_id(params[:id])
      log_and_render_404 unless @item
    end

    def scoper
      create? ? current_account.groups : current_account.groups_from_cache
    end

    def initialize_agents
      prepare_array_fields [:agent_ids]
      @agent_ids = params[cname][:agent_ids]
    end

    def load_objects
      super(groups_filter(current_account.groups).order(:name))
    end

    def sanitize_params
      if params[cname][:group_type].present?
        group_type_id = GroupType.group_type_id(params[cname][:group_type])
        params[cname][:group_type] = group_type_id
      end
      params[cname][:unassigned_for] = UNASSIGNED_FOR_MAP[params[cname][:unassigned_for]]
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
        @item.agent_groups = agent_groups
      end
    end

    def groups_filter(groups)
      @group_filter.conditions.each do |key|
        clause = groups.api_filter(@group_filter)[key.to_sym] || {}
        groups = groups.where("group_type" => GroupType.group_type_id(clause[:conditions][:group_type]))
      end
      groups
    end
  
    def render_success_response
      render_201_with_location(item_id: @item.id)
    end 
end
