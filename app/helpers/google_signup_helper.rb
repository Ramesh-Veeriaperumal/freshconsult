module GoogleSignupHelper

  def update_google_domain
    @account.update_attribute(:google_domain, @google_domain)
  end

  def create_user_session(oauth_user)
    if oauth_user.privilege?(:manage_account)
     if update_google_domain
        recreate_user_session
        set_redis_and_redirect(@google_domain, @email, @account, @uid)
     end
    else
      delete_user_session
    end
  end

  def recreate_user_session
    unless @check_session.nil?
      user = @account.users.find_by_email(@email)
      @check_session.destroy
      user ||= create_user(@account, @name, @email)
      create_auth(user, @uid, @account.id)
    end
  end

  def delete_user_session
    @check_session.destroy unless @check_session.nil?
    flash[:notice] = t(:'flash.general.insufficient_privilege.admin')
    render :associate_google
  end

end