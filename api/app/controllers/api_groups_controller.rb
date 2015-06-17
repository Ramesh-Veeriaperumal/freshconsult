class ApiGroupsController < ApiApplicationController
  before_filter :build_agents, only: [:create, :update]
  before_filter :drop_agents, only: [:update]

  def index
    @groups = @groups.find(:all, include: :agent_groups)
  end

  private

    def validate_params
      params[cname].permit(*(ApiConstants::GROUP_FIELDS))
      group = ApiGroupValidation.new(params[cname], @item)
      render_custom_errors(group, group.error_options) unless group.valid?
    end

    def scoper
      current_account.groups
    end

    def api_group_url(id)
      (url_for controller: 'api_groups') + '.' + id.to_s
    end

    def build_agents
      agents_data = params[:group][:agent_list]
      agents_data.split(',').each { |agent| @group.agent_groups.build(user_id: agent) } unless agents_data.blank?
    end

    def drop_agents
      @group.agent_groups.delete_all unless @group.agent_groups.nil?
    end
end
