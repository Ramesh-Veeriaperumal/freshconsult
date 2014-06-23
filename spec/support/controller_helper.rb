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
    agents = @account.account_managers
    agents.each do |agent|
      return agent if agent.can_view_all_tickets?
    end
    add_test_agent(@account)
  end
end
