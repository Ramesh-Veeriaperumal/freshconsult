class Admin::SandboxesController < ApiApplicationController
  include HelperConcern
  include SandboxConstants

  decorate_views(decorate_objects: [:index])

  before_filter :check_feature
  before_filter :destroy?, only: [:destroy]

  def create
    current_account.mark_as!(:production_with_sandbox)
    ::Admin::Sandbox::CreateAccountWorker.perform_async({:account_id => current_account.id, :user_id => current_user.id})
  end

  def index
    super
    response.api_meta =  current_account.account_additional_settings.additional_settings[:sandbox]
  end

  def destroy
    @item.mark_as!(:destroy_sandbox)
    ::Admin::Sandbox::DeleteWorker.perform_async
    head 204
  end

  private

  def check_feature
    return if current_account.sandbox_lp_enabled?
    render_request_error(:require_feature, 403, feature: 'sandbox')
  end

  def feature_name
    FeatureConstants::SANDBOX
  end

  def destroy?
    render_request_error(:access_restricted, 403) unless @item && @item.try(:[],:sandbox_account_id) && !@item.destroy_sandbox?
  end

  def restricted_error_sandbox_account
    render_request_error(:cant_create_sandbox_in_a_sandbox_account, 409)
  end

  def restricted_error
    render_request_error(:action_restricted, 403, action: action, reason: I18n.t('sandbox.error')[action])
  end

  def load_objects
    @items = [current_account.sandbox_job].compact
  end

  def load_object
    @item = current_account.sandbox_job
    log_and_render_404 unless @item

  end

  def build_object  
    @item = current_account.create_sandbox_job
  end

  def before_build_object
    return restricted_error_sandbox_account if current_account.sandbox?
    restricted_error if current_account.sandbox_job.present?
  end

end