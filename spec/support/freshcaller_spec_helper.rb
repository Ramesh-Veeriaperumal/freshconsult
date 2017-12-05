module FreshcallerSpecHelper
  def create_customer_with_phone
    customer = FactoryGirl.build(
      :user,
      account: @account,
      email: Faker::Internet.email,
      user_role: Hash[*User::USER_ROLES.map { |i| [i[0], i[2]] }.flatten][:customer],
      phone: Faker::PhoneNumber.phone_number
    )
    customer.save
    customer
  end

  def create_test_freshcaller_account
    freshcaller_account = @account.build_freshcaller_account(
      freshcaller_account_id: 1,
      domain: 'localhost.test.domain'
    )
    freshcaller_account.save
    @account.make_current.add_feature :freshcaller
    @account.reload
  end

  def create_test_freshcaller_agent
    Freshcaller::Agent.create(account_id: @account.id, agent_id: @agent.id, fc_enabled: true, fc_user_id: 1)
  end

  def freshcaller_account_signup
    {
      :freshcaller_account_id => 1,
      :freshcaller_account_domain => "aljgalaskgh.ngrok.io",
      :agent =>{
        :id => 1,
        :email => "test@freshdesk.com"
      }
    }
  end

  def freshcaller_domain_error
    {
      :errors => {
        :account_full_domain => "Domain already taken"
      }
    }
  end

  def freshcaller_account_linking
    { user_emails: [Faker::Internet.email, Faker::Internet.email], freshcaller_account_id: 2, freshcaller_account_domain: Faker::Internet.url } 
  end

  def freshcaller_account_linking_error
    { error: 'Account Not found'}
  end
end
