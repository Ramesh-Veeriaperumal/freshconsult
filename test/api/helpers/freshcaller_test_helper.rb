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
    ::Freshcaller::Account.where(account_id: @account.id).destroy_all
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

  def create_freshcaller_enabled_agent_with_custom_user_id(user_id: 1, agent_id: @agent.agent.id)
    freshcaller_agent = Account.current.freshcaller_agents.new(
      agent_id: agent_id,
      fc_user_id: user_id,
      fc_enabled: true
    )
    freshcaller_agent.save
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

  def link_url
    'https://test.freshcaller.com/link_account'
  end

  def add_agent_url
    'https://localhost.test.domain/users'
  end

  def signup_url
    "#{FreshcallerConfig['signup_domain']}/accounts"
  end

  def stub_link_account_success(email)
    response_hash = {
      user_details: [
        {
          email: email,
          user_id: 1234
        }
      ],
      freshcaller_account_id: 1234,
      freshcaller_account_domain: 'test.freshcaller.com'
    }
    @req = stub_request(:put, link_url).to_return(body: response_hash.to_json,
                                                  status: 200,
                                                  headers: { 'Content-Type' => 'application/json' })
  end

  def stub_link_account_success_with_null_user_detail(email)
    response_hash = {
      user_details: [
        {
          email: email,
          user_id: 1234
        },
        nil
      ],
      freshcaller_account_id: 1234,
      freshcaller_account_domain: 'test.freshcaller.com'
    }
    @req = stub_request(:put, link_url).to_return(body: response_hash.to_json,
                                                  status: 200,
                                                  headers: { 'Content-Type' => 'application/json' })
  end

  def stub_link_account_access_restricted
    response_hash = {
      error: 'No Access',
      error_code: 'access_restricted'
    }
    @req = stub_request(:put, link_url).to_return(body: response_hash.to_json,
                                                  status: 200,
                                                  headers: { 'Content-Type' => 'application/json' })
  end

  def stub_link_account_password_incorrect
    response_hash = {
      error: 'password_incorrect',
      error_code: 'password_incorrect'
    }
    @req = stub_request(:put, link_url).to_return(body: response_hash.to_json,
                                                  status: 200,
                                                  headers: { 'Content-Type' => 'application/json' })
  end

  def stub_link_account_invalid_domain
    @req = stub_request(:put, link_url).to_return(body: '{}',
                                                  status: 404,
                                                  headers: { 'Content-Type' => 'application/json' })
  end

  def stub_link_account_access_denied
    response_hash = {
      access: 'denied'
    }
    @req = stub_request(:put, link_url).to_return(body: response_hash.to_json,
                                                  status: 403,
                                                  headers: { 'Content-Type' => 'application/json' })
  end

  def stub_link_account_unprocessible_entity
    @req = stub_request(:put, link_url).to_return(body: '{}',
                                                  status: 422,
                                                  headers: { 'Content-Type' => 'application/json' })
  end

  def stub_create_error
    response_hash = {
      success: false,
      errors: {
        user_email: ['spam email'],
        spam_email: true
      },
      error_code: 'spam_email'
    }
    @req = stub_request(:post, signup_url).to_return(body: response_hash.to_json,
                                                     status: 200,
                                                     headers: { 'Content-Type' => 'application/json' })
  end

  def stub_create_success
    response_hash = {
      user: {
        id: 1234
      },
      freshcaller_account_id: 1234,
      freshcaller_account_domain: 'test.freshcaller.com'
    }
    @req = stub_request(:post, signup_url).to_return(body: response_hash.to_json,
                                                     status: 200,
                                                     headers: { 'Content-Type' => 'application/json' })
  end

  def stub_create_spam_email_error
    response_hash = {
      success: false,
      errors: {
        user_email: ['spam email'],
        spam_email: true
      },
      error_code: 'spam_email'
    }
    @req = stub_request(:post, signup_url).to_return(body: response_hash.to_json,
                                                     status: 422,
                                                     headers: { 'Content-Type' => 'application/json' })
  end

  def stub_create_domain_taken_error
    response_hash = {
      success: false,
      errors: {
        domain: ['taken']
      },
      error_code: 'domain_taken'
    }
    @req = stub_request(:post, signup_url).to_return(body: response_hash.to_json,
                                                     status: 200,
                                                     headers: { 'Content-Type' => 'application/json' })
  end

  def stub_create_unknown_error
    response_hash = {
      success: false,
      errors: {
        domain: ['taken']
      },
      error_code: 'unknown_error'
    }
    @req = stub_request(:post, signup_url).to_return(body: response_hash.to_json,
                                                     status: 400,
                                                     headers: { 'Content-Type' => 'application/json' })
  end

  def stub_create_users
    response_hash = {
      data: {
        id: 111
      }
    }
    @req = stub_request(:post, add_agent_url).to_return(body: response_hash.to_json,
                                                        status: 200,
                                                        headers: { 'Content-Type' => 'application/json' })
  end

  def stub_create_users_already_present_error
    response_hash = {
      errors: [{
        detail: 'Agent has already been taken'
      }]
    }
    @req = stub_request(:post, add_agent_url).to_return(body: response_hash.to_json,
                                                        status: 400,
                                                        headers: { 'Content-Type' => 'application/json' })
  end

  def stub_create_users_agent_limit_error
    response_hash = {
      errors: [{
        detail: 'Please purchase extra to add new agents'
      }]
    }
    @req = stub_request(:post, add_agent_url).to_return(body: response_hash.to_json,
                                                        status: 400,
                                                        headers: { 'Content-Type' => 'application/json' })
  end

  def remove_stubs
    remove_request_stub(@req)
  end
end
