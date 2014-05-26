module ControllerHelper

  def log_in(user)
    user.should_not be_nil
    session = UserSession.create!(user)
    session.should be_valid
    session.save
  end

  def login_admin()
    agent = get_admin
    log_in(agent)
  end

  def get_admin()
    agent = @account.account_managers.first
    unless agent
      agent = add_test_agent(@account)
    end
    agent
  end
end
