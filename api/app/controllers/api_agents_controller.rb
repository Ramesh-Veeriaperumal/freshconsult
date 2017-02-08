class ApiAgentsController < ApiApplicationController
  def me
    render "#{controller_path}/show"
  end

  def update
    assign_protected
    agent_delegator = AgentDelegator.new(params[cname].slice(:role_ids, :group_ids))
    if agent_delegator.invalid?
      render_custom_errors(agent_delegator, true)
    elsif !@item.update_attributes(params[cname])
      render_custom_errors
    end
  end

  def destroy
    @item.user.make_customer
    head 204
  end

  private

    def after_load_object
      if ((update? || destroy?) && !User.current.can_edit_agent?(@item)) || (destroy? && User.current.id == @item.user_id)
        Rails.logger.error "API V2 AgentsController Action: #{action_name}, UserId: #{@item.user_id}, CurrentUser: #{User.current.id}"
        render_request_error(:access_denied, 403)
      end
    end

    def load_object
      params[:id] = api_current_user.id if me?
      @item = scoper.find_by_user_id(params[:id])
      log_and_render_404 unless @item
    end

    def validate_params
      params[cname].permit(*(AgentConstants::UPDATE_FIELDS))
      agent = AgentValidation.new(params[cname], @item, string_request_params?)
      render_custom_errors(agent, true)  unless agent.valid?
    end

    def sanitize_params
      prepare_array_fields [:role_ids, :group_ids]
      params_hash = params[cname]
      user_attributes = AgentConstants::USER_FIELDS & params_hash.keys
      params_hash[:user_attributes] = params_hash.extract!(*user_attributes)
      params_hash[:user_attributes][:id] = @item.try(:user_id)
      ParamsHelper.assign_and_clean_params({ signature: :signature_html, ticket_scope: :ticket_permission }, params_hash)
    end

    def validate_filter_params
      params.permit(*AgentConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      @agent_filter = AgentFilterValidation.new(params)
      render_errors(@agent_filter.errors, @agent_filter.error_options) unless @agent_filter.valid?
    end

    def load_objects
      super(
        if User.current.privilege?(:manage_users)
          # Preloading user as 'includes' introduces an additional outer join to users table while inner join with user already exists
          agents_filter(scoper).preload(:user).order(:name)
        else
          scoper
        end
      )
    end

    def assign_protected
      if params[cname][:user_attributes].key?(:role_ids)
        params[cname][:role_ids] = params[cname][:user_attributes][:role_ids]
        # This is to forcefully call user callbacks only when role_ids are there.
        # As role_ids are not part of user_model(it is an association_reader), agent.update_attributes won't trigger user callbacks since user doesn't have any change.
        @item.user.send(:attribute_will_change!, :role_ids_changed)
      end
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

    def me?
      @me ||= current_action?('me')
    end

    def allowed_to_access?
      me? ? true : super
    end

    def set_custom_errors(item = @item)
      ErrorHelper.rename_error_fields(AgentConstants::FIELD_MAPPINGS, item)
    end

    def error_options_mappings
      AgentConstants::FIELD_MAPPINGS
    end
end
