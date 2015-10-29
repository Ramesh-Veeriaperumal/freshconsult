class ApiAgentsController < ApiApplicationController
  private

    def load_object
      @item = scoper.find_by_user_id(params[:id])
      head :not_found unless @item
    end

    def validate_filter_params
      params.permit(*AgentConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      @agent_filter = AgentFilterValidation.new(params)
      render_errors(@agent_filter.errors, @agent_filter.error_options) unless @agent_filter.valid?
    end

    def load_objects
      super agents_filter(scoper.list)
    end

    def agents_filter(agents)
      @agent_filter.conditions.each do |key|
        clause = agents.api_filter(@agent_filter)[key.to_sym] || {}
        agents = agents.where(clause[:conditions])
      end
      agents
    end

    def scoper
      current_account.all_agents
    end
end
