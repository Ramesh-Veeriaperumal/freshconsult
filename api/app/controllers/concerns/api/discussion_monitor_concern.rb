module Api::DiscussionMonitorConcern
  extend ActiveSupport::Concern
  included do
    before_filter :access_denied, only: [:follow, :unfollow, :followed_by, :is_following], unless: :logged_in?
    before_filter :permit_toggle_params, :fetch_monitorship, only: [:follow, :unfollow]
    before_filter :validate_user_id, :allow_monitor?, only: [:followed_by, :is_following]
    before_filter :fetch_active_monitorship_for_user, only: [:is_following]
  end

  def follow
    if @monitorship.update_attributes(active: true, portal_id: current_portal.id)
      head 204
    else
      render_error(@monitorship.errors)
    end
  end

  def unfollow
    if @monitorship.update_attributes(active: false)
      head 204
    else
      render_error(@monitorship.errors)
    end
  end

  def is_following
    if @monitorship
      head 204
    else
      head 404
    end
  end

  def followed_by
    @topics = paginate_items(current_account.topics.followed_by(params[:user_id]))
    render partial: '/api_discussions/topics/topic_list'
  end

  private

  def fetch_monitorship
    user_id = params[cname][:user_id] || current_user.id
    @monitorship = Monitorship.find_or_initialize_by_user_id_and_monitorable_id_and_monitorable_type(
      user_id, @item.id, @item.class.to_s)
  end

  def fetch_active_monitorship_for_user
    @monitorship = Monitorship.find_by_user_id_and_monitorable_id_and_monitorable_type_and_active(
      params[:user_id], params[:id], cname.capitalize, true)
  end

  def permit_toggle_params
    toggle_params = [(:user_id if privilege?(:manage_users))] # what if the user_id is same as current_user id
    params[cname].permit(*toggle_params)
    validate params[cname]
  end

  def validate_user_id
    validate params
    params[:user_id] ||= current_user.id
  end

  def validate(params_hash)
    monitor = ApiDiscussions::MonitorValidation.new(params_hash)
    render_error monitor.errors unless monitor.valid?
  end

  def allow_monitor?
    render_invalid_user_error unless params[:user_id] == current_user.id || privilege?(:manage_forums)
  end
end
