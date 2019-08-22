class ApiAgentsController < ApiApplicationController
  include HelperConcern

  skip_before_filter :check_privilege, only: :revert_identity
  before_filter :check_gdpr_pending?, only: :complete_gdpr_acceptance
  SLAVE_ACTIONS = %w[index achievements].freeze

  def check_edit_privilege
    if current_account.freshid_enabled?
      AgentConstants::RESTRICTED_PARAMS.any? do |key|
        if @item.user_changes.key?(key)
          @item.errors[:base] << :cannot_edit_inaccessible_fields
          return false
        end
      end
    end
    true
  end

  def update
    assign_protected
    return unless validate_delegator(@item, params[cname].slice(:role_ids, :group_ids, :available, :avatar_id))

    params[cname][:user_attributes].each do |k, v|
      @item.user.safe_send("#{k}=", v)
    end
    @item.user_changes = @item.user.agent.user_changes || {}
    @item.user_changes.merge!(@item.user.changes)
    return render_custom_errors(@item) unless check_edit_privilege
    if params[cname].key?(:group_ids)
      group_ids = params[cname].delete(:group_ids)
      @item.build_agent_groups_attributes(group_ids)
    end
    return if @item.update_attributes(params[cname].except(:user_attributes))

    render_custom_errors
  end

  def destroy
    @item.user.make_customer
    head 204
  end

  def complete_gdpr_acceptance
    User.current.remove_gdpr_preference
    User.current.save ? (head 204) : render_errors(gdpr_acceptance: :not_allowed_to_accept_gdpr)
  end

  def enable_undo_send
    head 400 unless current_account.undo_send_enabled?
    api_current_user.toggle_undo_send(true) unless api_current_user.enabled_undo_send?
    head :no_content
  end

  def disable_undo_send
    head 400 unless current_account.undo_send_enabled?
    api_current_user.toggle_undo_send(false) if api_current_user.enabled_undo_send?
    head :no_content
  end

  private

    def constants_class
      :AgentConstants.to_s.freeze
    end

    def agent_delegator_params
      {}
    end

    def after_load_object
      if (update? && (!User.current.can_edit_agent?(@item) || !agent_update_allowed?)) || (destroy? && (!User.current.can_edit_agent?(@item) || current_user_update?))
        Rails.logger.error "API V2 AgentsController Action: #{action_name}, UserId: #{@item.user_id}, CurrentUser: #{User.current.id}"
        render_request_error(:access_denied, 403)
      end
    end

    def load_object
      @item = api_current_user.id if me? || current_action?('revert_identity')
      @item ||= scoper.find_by_user_id(params[:id])
      log_and_render_404 unless @item
    end

    def remove_ignore_params
      params[cname].except!(AgentConstants::IGNORE_PARAMS)
    end

    def validate_params
      params[cname].permit(*AgentConstants::UPDATE_FIELDS)
      agent = AgentValidation.new(params[cname], @item, string_request_params?)
      render_custom_errors(agent, true) unless agent.valid?
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

    def load_objects(scoper_options = nil)
      return super(scoper_options) if scoper_options
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
        @item.user.safe_send(:attribute_will_change!, :role_ids_changed)
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

    def check_gdpr_pending?
      render_request_error :access_denied, 403 unless User.current.gdpr_pending?
    end

    def me?
      @me ||= current_action?('me')
    end

    def current_user_update?
      (@item.user_id == User.current.id)
    end

    def agent_update_allowed?
      User.current.privilege?(:manage_availability) ? true : current_user_update?
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
