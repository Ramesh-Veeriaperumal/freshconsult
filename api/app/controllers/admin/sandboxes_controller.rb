class Admin::SandboxesController < ApiApplicationController
  include HelperConcern
  include SandboxConstants
  include Redis::RedisKeys
  include Redis::OthersRedis

  decorate_views(decorate_objects: [:index])

  before_filter :validate_merge_params, only: [:merge]
  before_filter :load_object, only: [:destroy, :diff, :merge]
  before_filter :destroy?, only: [:destroy]
  before_filter :diff?, only: [:diff]
  before_filter :merge?, only: [:merge]

  def create
    current_account.mark_as!(:production_with_sandbox)
    ::Admin::Sandbox::CreateAccountWorker.perform_async({:account_id => current_account.id, :user_id => current_user.id})
  end

  def index
    super
    sandbox_details = current_account.account_additional_settings.additional_settings[:sandbox] || {}
    response.api_meta = sandbox_details.merge!(last_diff: @items.first.try(:last_diff))
  end

  def diff
    if recent_diff? && (@item.sandbox_complete? || (@item.diff_complete? && params[:force]))
      @item.mark_as!(:diff_in_progress)
      ::Admin::Sandbox::DiffWorker.perform_async
      @items = {status: PROGRESS_KEYS_BY_TOKEN[@item.status]}
    elsif @item.diff_complete?
      @items = @item.diff
    else
      @items = {status: PROGRESS_KEYS_BY_TOKEN[@item.status]}
    end
    response.api_root_key = :sandbox
    response.api_meta = {conflict: @item.conflict?}
  end

  def merge
    upload_diff_template(params[:sandbox], params[:meta])
    @item.mark_as!(:merge_in_progress)
    ::Admin::Sandbox::MergeWorker.perform_async
    @data = {status: PROGRESS_KEYS_BY_TOKEN[@item.status]}
    response.api_root_key = :sandbox
  end

  def destroy
    @item.mark_as!(:destroy_sandbox)
    ::Admin::Sandbox::DeleteWorker.perform_async(event: SANDBOX_DELETE_EVENTS[:deactivate])
    head 204
  end

  private

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

  def diff?
    restricted_error if @item.status < STATUS_KEYS_BY_TOKEN[:sandbox_complete]
  end

  def merge?
    render_request_error(:access_restricted, 403) if @item.conflict? || !@item.diff_complete?
  end

  def build_object
    @item = current_account.create_sandbox_job
  end

  def before_build_object
    return restricted_error_sandbox_account if current_account.sandbox?
    restricted_error if current_account.sandbox_job.present?
  end

  def recent_diff?
    !(@item.last_diff.present? && (@item.last_diff > (Time.now.utc - get_others_redis_key(SANDBOX_DIFF_RATE_LIMIT).to_i.minutes)))
  end

  private
    def validate_merge_params
      params.permit(*SandboxConstants::MERGE_FIELDS, *ApiConstants::DEFAULT_PARAMS)
    end

    def upload_diff_template(diff_data, meta)
      template_data = {diff: diff_data, meta: meta}
      path = "sandbox/#{current_account.id}/#{@item.sandbox_account_id}_diff_template.json"
      AwsWrapper::S3.put(S3_CONFIG[:bucket], path, template_data.to_json, server_side_encryption: 'AES256') # PRE-RAILS: V1 wrapper had default encryption
    end

end