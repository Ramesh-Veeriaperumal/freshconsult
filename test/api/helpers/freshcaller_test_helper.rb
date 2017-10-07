module Freshcaller::TestHelper
  def create_freshcaller_account
    freshcaller_account = @account.build_freshcaller_account(
      freshcaller_account_id: 1,
      domain: 'localhost.test.domain'
    )
    freshcaller_account.save
    @account.reload
  end

  def delete_freshcaller_account
    @account.freshcaller_account.delete
    @account.reload
  end

  def create_freshcaller_enabled_agent
    freshcaller_agent = @agent.agent.build_freshcaller_agent(
      fc_user_id: 1,
      fc_enabled: true
    )
    freshcaller_agent.save
    @agent.agent.reload
  end

  def create_freshcaller_disabled_agent
    freshcaller_agent = @agent.agent.build_freshcaller_agent(
      fc_user_id: 1,
      fc_enabled: false
    )
    freshcaller_agent.save
    @agent.agent.reload
  end

  def delete_freshcaller_agent
    @agent.agent.freshcaller_agent.delete
    @agent.agent.reload
  end
end
