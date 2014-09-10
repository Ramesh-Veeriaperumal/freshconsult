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
    agents = RSpec.configuration.account.account_managers
    agents.each do |agent|
      return agent if agent.can_view_all_tickets?
    end
    add_test_agent(RSpec.configuration.account)
  end

  def clear_email_config
    unless RSpec.configuration.account.primary_email_config.to_email == "support@#{@account.full_domain}"
      RSpec.configuration.account.email_configs.destroy_all
      ec = RSpec.configuration.account.email_configs.build({:to_email => "support@#{@account.full_domain}", 
                                    :reply_email => "support@#{@account.full_domain}", 
                                    :active => true, 
                                    :primary_role => true, 
                                    :name => "Test Account"})
      ec.save(:validate => false)
      RSpec.configuration.account.reload
    end
  end
end
