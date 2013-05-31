module Helpdesk::ShowVersion

  include Redis::RedisKeys
  include Redis::TicketsRedis

  def set_show_version
    if cookies[:new_details_view].present?
      # Expiry set to 50 days
      set_tickets_redis_key(show_version_key, (cookies[:new_details_view].eql?("true") ? "1" : "0"),  86400 * 50)
      cookies.delete(:new_details_view) 
    end
    @new_show_page = ($get_tickets_redis_key(show_version_key) != "0")
  rescue Exception => e
    NewRelic::Agent.notice_error(e)
    return
  end

  def show_version_key
    HELPDESK_TKTSHOW_VERSION % { :account_id => current_account.id, :user_id => current_user.id }
  end

end