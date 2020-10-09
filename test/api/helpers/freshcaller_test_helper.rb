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

  def update_agent_url(fc_user_id)
    "https://localhost.test.domain/users/#{fc_user_id}"
  end

  def signup_url
    "#{FreshcallerConfig['signup_domain']}/accounts"
  end
  
  def business_calendar_url
    'https://localhost.test.domain/ufx/v1/business_hours'
  end

  def business_calendar_create_url
    business_calendar_url
  end

  
  def business_calendar_update_url(id)
    format('%{url}/%{id}', url: business_calendar_url, id: id)
  end
  
  def business_calendar_delete_url(calendar_id)
    format('%{url}/%{id}', url: business_calendar_url, id: calendar_id)
  end

  def business_calendar_show_url(calendar_id)
    format('%{url}/%{id}', url: business_calendar_url, id: calendar_id)
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
      'data' => {
        'id' => '111',
        'attributes' => { 'deleted' => false }
      }
    }
    @req = stub_request(:post, add_agent_url).to_return(body: response_hash.to_json,
                                                        status: 200,
                                                        headers: { 'Content-Type' => 'application/json' })
  end

  def stub_create_users_already_present(fc_user_id, is_deleted)
    response_hash = {
      'data' => {
        'id' => fc_user_id.to_s,
        'attributes' => { 'deleted' => is_deleted }
      }
    }
    @req = stub_request(:patch, update_agent_url(fc_user_id)).to_return(body: response_hash.to_json,
                                                                        status: 200,
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

  def stub_business_calendar_delete_success(id)
    stub_request(:delete, business_calendar_show_url(id)).to_return(body: {}.to_json,
                                                                      status: 204,
                                                                      headers: { 'Content-Type' => 'application/json' })
  end

  def stub_business_calendar_delete_unauthorized(id)
    response_hash = {
      error_type: 'user_unauthorized',
      message: 'The email-id/password/token is incorrect.'
    }
    stub_request(:delete, business_calendar_show_url(id)).to_return(body: response_hash.to_json,
                                                                      status: 401,
                                                                      headers: { 'Content-Type' => 'application/json' })
  end

  def stub_business_calendar_delete_invalid_authentication(id)
    response_hash = {
      result: 'unauthorized',
      error: {
        message: 'Access denied'
      }
    }
    stub_request(:delete, business_calendar_show_url(id)).to_return(body: response_hash.to_json,
                                                                      status: 403,
                                                                      headers: { 'Content-Type' => 'application/json' })
  end

  def stub_business_calendar_delete_not_found(id)
    response_hash = {
      errors: {
        message: 'Id does not exist'
      }
    }
    stub_request(:delete, business_calendar_show_url(id)).to_return(body: response_hash.to_json,
                                                                      status: 404,
                                                                      headers: { 'Content-Type' => 'application/json' })
  end

  def remove_stubs
    remove_request_stub(@req)
  end

  def stub_caller_bc_create_success(args)
    stub_request(:post, business_calendar_create_url).to_return(body: (args[:phone].presence || {}).to_json,
                                                                status: 201,
                                                                headers: { 'Content-Type' => 'application/json' })
  end

  def stub_caller_business_calendar_update_success(id, args)
    stub_request(:put, business_calendar_update_url(id)).to_return(body: (args[:phone].presence || {}).to_json,
                                                                status: 200,
                                                                headers: { 'Content-Type' => 'application/json' })
  end

  def stub_bc_create_failure
    stub_request(:post, business_calendar_create_url).to_return(body: { "errors": [
                                                                                    'Invalid data'
                                                                                  ]
                                                                      }.to_json,
                                                                status: 422,
                                                                headers: { 'Content-Type' => 'application/json' })
  end

  def stub_bc_update_failure(id)
    stub_request(:put, business_calendar_update_url(id)).to_return(body: { "errors": [
                                                                                      'Invalid data'
                                                                                  ]
                                                                      }.to_json,
                                                                status: 422,
                                                                headers: { 'Content-Type' => 'application/json' })
  end

  def stub_show_business_calendar_success(id)
    response_hash = {
      id: id,
      name: 'caller calendar sample',
      description: 'string',
      time_zone: 'American Samoa',
      default: true,
      holidays: [
        { name: 'hol 1', date: 'aug 15'},
        { name: 'hol 2', date: 'may 20'},
        { name: 'hol 3', date: 'jun 09'}
      ],
      channel_business_hours: caller_channel_business_hours_sample[:channel_business_hours]
    }
    stub_request(:get, business_calendar_show_url(id)).to_return(body: response_hash.to_json,
                                                                status: 200,
                                                                headers: { 'Content-Type' => 'application/json' })
  end

  def stub_show_business_calendar_failure(id)
    stub_request(:get, business_calendar_show_url(id)).to_return(body: {}.to_json,
                                                                status: 503,
                                                                headers: { 'Content-Type' => 'application/json' })
  end

  def stub_freshcaller_show_bc_failure(id)
    stub_request(:get, business_calendar_show_url(id)).to_return(body: {}.to_json,
                                                                 status: 404,
                                                                 headers: { 'Content-Type' => 'application/json' })
  end
end
