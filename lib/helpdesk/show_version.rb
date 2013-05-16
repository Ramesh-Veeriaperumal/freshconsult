module Helpdesk::ShowVersion

  include RedisKeys

  def set_show_version
    if cookies[:new_details_view].present?
      $redis_secondary.set(show_version_key, cookies[:new_details_view].eql?("true") ? "1" : "0")
      $redis_secondary.expire(show_version_key, 86400 * 50)
      # Expiry set to 50 days
      cookies.delete(:new_details_view) 
    end
    @new_show_page = ($redis_secondary.get(show_version_key) == "1")
  rescue Exception => e
    NewRelic::Agent.notice_error(e)
    return
  end

  def show_version_key
    HELPDESK_TKTSHOW_VERSION % { :account_id => current_account.id, :user_id => current_user.id }
  end

end