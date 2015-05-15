module Api::DiscussionMonitorConcern
  extend ActiveSupport::Concern
  included do
    before_filter :access_denied, :only => [:follow, :unfollow], :unless => :logged_in? 
    before_filter :permit_toggle_params, :fetch_monitorship, :only => [:follow, :unfollow]
  end

  def follow
    if @monitorship.update_attributes({:active => true, :portal_id => current_portal.id})
      head 204
    else
      render_error(@monitorship.errors)   
    end
  end

  def unfollow
    if @monitorship.update_attributes({:active => false})
      head 204
    else
      render_error(@monitorship.errors)   
    end
  end

  private

  def fetch_monitorship
    user_id = params[cname][:user_id] || current_user.id
    @monitorship = Monitorship.find_or_initialize_by_user_id_and_monitorable_id_and_monitorable_type(
      user_id, @item.id, @item.class.to_s)
  end

  def permit_toggle_params
    toggle_params = [(:user_id if privilege?(:manage_users))]
    params[cname].permit(*toggle_params)
    monitor = ApiDiscussions::MonitorValidation.new(params[cname]) 
    unless monitor.valid?
      render_error monitor.errors
    end
  end
end
