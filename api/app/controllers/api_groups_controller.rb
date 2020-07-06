class ApiGroupsController < ApiApplicationController
  include GroupConstants
  include OmniChannelRouting::Util
  decorate_views
  before_filter :prepare_agents, only: [:create, :update]

  def index
    if include_omni_channel_groups?
      @omni_channel_groups = []
      ocr_path = OCR_PATHS[:get_groups]
      ocr_path = [ocr_path, { auto_assignment: params[:auto_assignment] }.to_query].join('?') if params[:auto_assignment]
      begin
        ocr_response = request_ocr(:admin, :get, ocr_path)
        @omni_channel_groups = JSON.parse(ocr_response).try(:[], 'ocr_groups')
      rescue Exception => e
        Rails.logger.info "Exception while fetching groups from OCR :: #{e.inspect}"
        NewRelic::Agent.notice_error(e)
      end
    end
    super
  end

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
      ParamsHelper.assign_and_clean_params({ allow_agents_to_change_availability: :toggle_availability, unassigned_for: :assign_time, auto_ticket_assign: :ticket_assign_type },
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
        read_access_agent_groups = @item.all_agent_groups.select { |ag| ag.write_access.blank? }
        read_access_agent_groups.select { |ag| @agent_ids.include?(ag.user_id) }.map(&:destroy)
        @item.agent_groups = agent_groups
      end
    end

    def groups_filter(groups)
      @group_filter.conditions.each do |key|
        clause = groups.api_filter(@group_filter)[key.to_sym] || {}
        next if clause.blank?

        groups = groups.where('group_type' => GroupType.group_type_id(clause[:conditions][:group_type])) if clause[:conditions][:group_type].present?
        groups = groups.where(clause[:conditions][@group_filter.safe_send(key).to_sym]) if @group_filter.respond_to?(key) && clause[:conditions][@group_filter.safe_send(key).to_sym].present?
      end
      groups
    end

    def render_success_response
      render_201_with_location(item_id: @item.id)
    end

    def group_params
      case true
      when agent_status_enabled? && round_robin_feature_enabled? && !service_group?
        update? ? UPDATE_FIELDS_WITH_STATUS_TOGGLE : FIELDS_WITH_STATUS_TOGGLE
      when agent_status_enabled? && !round_robin_feature_enabled? && !service_group?
        update? ? UPDATE_FIELDS_WITH_STATUS_TOGGLE_WITHOUT_TICKET_ASSIGN : FIELDS_WITH_STATUS_TOGGLE_WITHOUT_TICKET_ASSIGN
      when round_robin_feature_enabled?
        update? ? UPDATE_FIELDS : FIELDS
      else
        update? ? UPDATE_FIELDS_WITHOUT_TICKET_ASSIGN : FIELDS_WITHOUT_TICKET_ASSIGN
      end
    end

    def agent_status_enabled?
      current_account.agent_statuses_enabled?
    end

    def round_robin_feature_enabled?
      current_account.features?(:round_robin)
    end

    def service_group?
      (params[cname][:group_type].present? && params[cname][:group_type] == FIELD_GROUP_NAME) ||
        (@item.present? && @item.group_type == GroupType.group_type_id(FIELD_GROUP_NAME))
    end

    def include_omni_channel_groups?
      params[:include].split(',').include?('omni_channel_groups') if params[:include]
    end
end
