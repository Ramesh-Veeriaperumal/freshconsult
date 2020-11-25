# frozen_string_literal: true

class Admin::Groups::AgentsController < ApiApplicationController
  include HelperConcern
  include AgentConstants
  decorate_views
  ALLOWED_FIELDS = [:agents].freeze

  def index
    super
    response.api_meta = { count: @items_count }
  end

  def update
    agent_delegator = Admin::Groups::AgentsDelegator.new(@item, agents: params[cname][:agents])
    if agent_delegator.valid?(action_name.to_sym)
      @item.build_agent_groups_attributes(build_agent_groups_update_list)
      if @item.save
        head 204
      else
        render_custom_errors(@item)
      end
    else
      render_errors(agent_delegator.errors, agent_delegator.error_options)
    end
  end

  private

    def build_agent_groups_update_list
      delete_user_ids = []
      added_user_ids = []
      old_user_ids = @group.all_agent_groups.pluck(:user_id)
      agent_update_data = params[cname][:agents]
      agent_update_data.each do |agent_data|
        if agent_data.key?(:deleted) && agent_data[:deleted]
          delete_user_ids << agent_data[:id]
        else
          added_user_ids << agent_data[:id]
        end
      end
      ([old_user_ids - delete_user_ids] + added_user_ids).uniq.join(',')
    end

    def validate_params
      if params[cname].blank?
        custom_empty_param_error
      else
        params[cname].permit(*ALLOWED_FIELDS)
        validator_klass = validation_class.new(params[cname], @item, {})
        render_custom_errors(validator_klass, true) if validator_klass.invalid?(params[:action].to_sym)
      end
    end

    def load_group
      @group = current_account.groups_from_cache.find { |group| group.id == params[:id].to_i }
    end

    def scoper
      load_group
      return if @group.blank?

      # Prloading agent, avatar and freshcaller_agent to reduce N+1 query in views
      @group.agents.includes([{ agent: :freshcaller_agent }, :avatar])
    end

    def load_objects(items = scoper, paginate = true)
      log_and_render_404 && return if @group.blank?

      super
    end

    def load_object
      load_group
      log_and_render_404 && return if @group.blank?
      @item = @group
    end

    def launch_party_name
      FeatureConstants::GROUP_MANAGEMENT_V2
    end

    def validation_class
      'Admin::Groups::AgentsValidation'.constantize
    end

    def validate_filter_params(additional_fields = INDEX_QUERY_PARAMS)
      super
      validator_klass = validation_class.new(params, @item, {})
      render_custom_errors(validator_klass, true) if validator_klass.invalid?(params[:action].to_sym)
    end

    def include_options
      {
        include: params[:include],
        write_access_user_ids: Account.current.agent_groups_ids_only_from_cache[:groups][@group.id] || []
      }
    end

    def decorator_options(options = include_options)
      super
    end
end
