module Admin::Social::FacebookAuthHelper
  def set_session_state
    session[:state] = Digest::MD5.hexdigest("#{Helpdesk::SECRET_3}#{Time.now.to_f}#{current_account.id}")
  end

  def make_fb_client(callback_url, account_redirect_url)
      Facebook::Oauth::FbClient.new(callback_url, false, account_redirect_url)
  end

end