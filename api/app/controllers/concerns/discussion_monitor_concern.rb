module DiscussionMonitorConcern
  extend ActiveSupport::Concern
  included do
    before_filter :validate_toggle_params, only: [:follow, :unfollow]
    before_filter :can_send_user?, only: [:followed_by, :is_following, :follow, :unfollow]
    before_filter :validate_follow_params, only: [:followed_by, :is_following]
    before_filter :find_monitorship, only: [:unfollow]
  end

  def follow
    fetch_monitorship
    if skip_update || @monitorship.update_attributes(active: true, portal_id: current_portal.id)
      head 204
    else
      render_error(@monitorship.errors)
    end
  end

  def unfollow
    if !@monitorship.active? || @monitorship.update_attributes(active: false)
      head 204
    else
      render_error(@monitorship.errors)
    end
  end

  def is_following
    fetch_active_monitorship_for_user
    if @monitorship
      head 204
    else
      head 404
    end
  end

  private

    def before_load_object
      can_send_user? if follow? || unfollow?
    end

    def skip_update
      @monitorship.active? && @monitorship.portal_id == current_portal.id
    end

    def fetch_monitorship
      @monitorship = get_monitorship(params).first_or_initialize
    end

    def find_monitorship
      @monitorship = get_monitorship(params).first
      head 404 unless @monitorship
    end

    def get_monitorship(params)
      user_id = params[cname][:user_id] || current_user.id
      monitorship = Monitorship.where(user_id: user_id,
                                      monitorable_id: @item.id, monitorable_type: @item.class.to_s)
    end

    def fetch_active_monitorship_for_user
      @monitorship = Monitorship.find_by_user_id_and_monitorable_id_and_monitorable_type_and_active(
        params[:user_id], params[:id], cname.capitalize, true)
    end

    def validate_toggle_params
      toggle_params = [(:user_id if privilege?(:manage_users))]
      params[cname].permit(*toggle_params)
      validate params[cname]
    end

    def validate_follow_params
      fields = "DiscussionConstants::#{action_name.upcase}_FIELDS".constantize
      params.permit(*fields, *ApiConstants::DEFAULT_PARAMS)
      validate params
      params[:user_id] ||= current_user.id
    end

    def validate(params_hash)
      monitor = ApiDiscussions::MonitorValidation.new(params_hash)
      render_error monitor.errors unless monitor.valid?
    end

    def can_send_user?
      if followed_by? || is_following?
        if params[:user_id].present? && params[:user_id] != current_user.id && !privilege?(:manage_forums)
          render_request_error(:access_denied, 403, id: params[:user_id])
        end
      else
        super
      end
    end

    def is_following?
      current_action?('is_following')
    end

    def follow?
      current_action?('follow')
    end

    def unfollow?
      current_action?('unfollow')
    end

    def followed_by?
      current_action?('followed_by')
    end
end
