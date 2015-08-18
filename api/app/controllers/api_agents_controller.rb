class ApiAgentsController < ApiApplicationController

  def index
    load_objects agents_filter(scoper).includes(:user)
  end

  def agents_filter(agents)
    @agent_filter.conditions.each do |key|
      clause = agents.api_filter(@agent_filter)[key.to_sym] || {}
      agents = agents.where(clause[:conditions])
    end
    agents
  end

  private
    def scoper
      current_account.all_agents
    end

    def load_object
      condition = 'user_id = ? '
      @item = scoper.where(condition, params[:id]).first
      head :not_found unless @item
    end

    def validate_filter_params
      params.permit(*AgentConstants::INDEX_AGENT_FIELDS, *ApiConstants::DEFAULT_PARAMS,
                    *ApiConstants::DEFAULT_INDEX_FIELDS)
      @agent_filter = AgentFilterValidation.new(params)
      render_error(@agent_filter.errors, @agent_filter.error_options) unless @agent_filter.valid?
    end
end
