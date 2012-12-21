class Support::LoginController < SupportController

  def new
    @user_session = current_account.user_sessions.new
    set_portal_page :user_login
  end

end