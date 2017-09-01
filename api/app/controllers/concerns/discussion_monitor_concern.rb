module DiscussionMonitorConcern
  extend ActiveSupport::Concern
  included do
    before_filter :validate_toggle_params, only: [:follow]

    # followed_by and is_following would not follow the before_load_object, load_object, after_load_object flow,
    # as both methods do not require the topic/forum object to be loaded. Hence privileged_to_send_user? is not part of before_laod_object.
    before_filter :privileged_to_send_user?, only: [:followed_by, :is_following]

    # For same reason above validate_follow_params is not part of after_load_object.
    before_filter :validate_follow_params, only: [:is_following, :unfollow]
    before_filter :validate_user_id, only: :followed_by

    # find_monitorship is not aprt of after_load_object as that would necessitate a unfollow? check in after_load_object.
    before_filter :find_monitorship, only: [:unfollow]
  end

  def follow
    fetch_monitorship
    if skip_update
      head 204
    elsif validate_follow_delegator
      return
    elsif @monitorship.update_attributes(active: true, portal_id: current_portal.id)
      head 204
    else
      render_errors(@monitorship.errors) # not_tested
    end
  end

  def unfollow
    if !@monitorship.active? || @monitorship.update_attributes(active: false)
      head 204
    else
      render_errors(@monitorship.errors)
    end
  end

  def is_following
    fetch_active_monitorship_for_user
    if @monitorship
      head 204
    else
      log_no_monitorship_and_render_404
    end
  end

  private

    # unfollow does not create a new object from user input, hence no validation.
    def validate_follow_delegator
      delegator = MonitorshipDelegator.new(@monitorship)
      if delegator.invalid?
        ErrorHelper.rename_error_fields({ user: :user_id }, delegator)
        render_errors delegator.errors
        return true
      end
    end

    def skip_update
      @monitorship.active? && @monitorship.portal_id == current_portal.id
    end

    def fetch_monitorship
      @monitorship = get_monitorship(params[cname]).first_or_initialize
    end

    def find_monitorship
      @monitorship = get_monitorship(params).first
      log_no_monitorship_and_render_404 unless @monitorship
    end

    def get_monitorship(params_hash)
      Monitorship.where(user_id: params_hash[:user_id],
                        monitorable_id: @item.id, monitorable_type: @item.class.to_s)
    end

    def fetch_active_monitorship_for_user
      @monitorship = Monitorship.find_by_user_id_and_monitorable_id_and_monitorable_type_and_active(
        params[:user_id], params[:id], cname.capitalize, true
      )
    end

    def validate_toggle_params
      toggle_params = DiscussionConstants::FOLLOW_FIELDS
      params[cname].permit(*toggle_params)
      validate_user_id params[cname]
    end

    def validate_follow_params
      fields = "DiscussionConstants::#{action_name.upcase}_FIELDS".constantize
      params.permit(*fields, *ApiConstants::DEFAULT_PARAMS)
      validate_user_id params
    end

    def validate_user_id(params_hash = params)
      monitor = ApiDiscussions::MonitorValidation.new(params_hash, nil, string_request_params?)
      render_errors monitor.errors, monitor.error_options unless monitor.valid?
      params_hash[:user_id] ||= api_current_user.id
    end

    def privileged_to_send_user?
      if params[:user_id].present? && not_current_user_id? && !privilege?(:manage_forums)
        render_request_error(:access_denied, 403, id: params[:user_id])
      end
    end

    def not_current_user_id?
      !params[:user_id].respond_to?(:to_i) || params[:user_id].to_i != api_current_user.id
    end

    def log_no_monitorship_and_render_404
      Rails.logger.debug "No Monitorship found for item #{params[:id]} with user id #{params[:user_id]}. controller : #{params[:controller]}"
      head 404
    end
end
