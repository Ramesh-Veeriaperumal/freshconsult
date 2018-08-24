module ControllerHelper

  def log_in(user)
    user.should_not be_nil
    session = UserSession.create!(user)
    session.should be_valid
    session.save
  end

  def login_admin()
    @agent = get_admin
    log_in(@agent)
  end

  def get_admin()
    users = @account.account_managers
    users.each do |user|
      return user if user.can_view_all_tickets? and user.privilege?(:manage_canned_responses) and !user.agent.occasional? and user.active?
    end
    add_test_agent(@account)
  end

  def clear_email_config
    @account.smtp_mailboxes.destroy_all
    unless @account.primary_email_config.to_email == "support@#{@account.full_domain}"
      @account.email_configs.destroy_all
      ec = @account.email_configs.build({:to_email => "support@#{@account.full_domain}", 
                                    :reply_email => "support@#{@account.full_domain}", 
                                    :active => true, 
                                    :primary_role => true, 
                                    :name => "Test Account"})
      ec.save(:validate => false)
      @account.reload
    end
  end
end
