# Note: FreshcallerAccount is treated as config rather than resource, in context of API design.
class Admin::FreshcallerAccountController < ApiApplicationController
  include HelperConcern
  include FreshcallerConcern
  include Freshcaller::Util

  skip_before_filter :build_object, only: [:create]
  before_filter :check_feature
  before_filter :load_agents, only: [:show]
  before_filter :validate_params, only: [:link, :update]
  before_filter :validate_linking, only: [:create, :link]
  before_filter :sanitize_params, only: [:update]

  attr_accessor :freshcaller_response

  def show
    head 204 unless @item
  end

  def create
    signup_account
    return render_client_error if client_error?

    load_agents
    render :show
  end

  def link
    @freshcaller_response = freshcaller_request(linking_params, freshcaller_link_url, :put)
    return render_client_error if client_error?

    link_freshcaller(freshcaller_response) if linked?
    load_agents
    render :show
  end

  def enable
    delegator = Admin::FreshcallerAccountDelegator.new(@item)
    if delegator.valid?
      @freshcaller_response = enable_integration
      return render_client_error if client_error?

      head 204
    else
      render_custom_errors(delegator, true)
    end
  end

  def disable
    delegator = Admin::FreshcallerAccountDelegator.new(@item)
    if delegator.valid?
      @freshcaller_response = disable_integration
      return render_client_error if client_error?

      head 204
    else
      render_custom_errors(delegator, true)
    end
  end

  def update
    delegator = Admin::FreshcallerAccountDelegator.new(scoper)
    if delegator.valid?
      Freshcaller::UpdateAgentsWorker.perform_async(agent_user_ids: cname_params[:agent_ids]) if cname_params[:agent_ids]

      head 204
    else
      render_custom_errors(delegator, true)
    end
  end

  def destroy
    delegator = Admin::FreshcallerAccountDelegator.new(@item)
    if delegator.valid?
      @freshcaller_response = disconnect_account
      return render_client_error if client_error?

      head 204
    else
      render_custom_errors(delegator, true)
    end
  end

  private

    def check_feature
      return if current_account.freshcaller_admin_new_ui_enabled?

      render_request_error(:require_feature, 403, feature: FeatureConstants::ADMIN_FRESHCALLER.join(',').titleize)
    end

    def scoper
      current_account.freshcaller_account
    end

    def agent_scoper
      current_account.freshcaller_agents.where(fc_enabled: true).preload(:user).select { |fc_agent| fc_agent.user }
    end

    def load_object
      @item = scoper
    end

    def load_agents
      @agents = agent_scoper || []
    end

    def validate_params
      validate_body_params
    end

    def sanitize_params
      prepare_array_fields Admin::FreshcallerAccountConstants::UPDATE_ARRAY_FIELDS
    end

    def validate_linking
      return render_request_error(:account_linked, 403) if scoper.present?

      return true if current_action?('create')

      linking_user = current_account.users.find_by_email(cname_params[:email])
      render_request_error(:action_restricted, 403, action: 'link',
                          reason: "user doesn't have enough privileges") unless privileged_user?(linking_user)
    end

    def validation_klass
      'Admin::FreshcallerAccountValidation'.constantize
    end

    def constants_class
      'Admin::FreshcallerAccountConstants'.constantize
    end
end
