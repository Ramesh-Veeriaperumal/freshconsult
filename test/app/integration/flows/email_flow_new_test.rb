require_relative '../../../api/api_test_helper'
require Rails.root.join('test', 'api', 'helpers', 'test_case_methods.rb')
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('spec', 'support', 'email_configs_helper.rb')

class EmailFlowTest < ActionDispatch::IntegrationTest
  include TestCaseMethods
  include UsersHelper
  include EmailConfigsHelper
  def test_new
    get '/email/new'
    assert_response 200
  end

  def test_create
    ticket_count = Account.current.tickets.count
    email_config = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    params = request_param(
      to_emails: [email_config.to_email],
      subject: 'Delivery Status Notification (Failure)',
      headers: "subject: Delivery Status Notification (Failure)  \r\n"
    )
    account_wrap do
      post '/email', params.merge(authentication_params)
    end
    assert_response 200
    assert_equal ticket_count + 1, Account.current.tickets.count
    assert_equal params[:subject], Account.current.tickets.last.subject
    assert_equal 'Hi', Account.current.tickets.last.description
  end

  def test_create_with_subject_with_encoding_invalid_chars
    email_config1 = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    email_config2 = create_email_config(email: "freightw@#{@account.full_domain}")
    params = request_param(
      to_emails: [email_config1.to_email, email_config2.to_email],
      subject: "Hi...St. Paul\xE2%80%99s Cathedral...",
      headers: "subject: ...St. Paul\xE2%80%99s Cathedral..."
    )
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    account_wrap do
      post '/email', params.merge(authentication_params)
    end
    assert_response 200
    encoded_subject = params[:subject].encode(Encoding::UTF_8, undef: :replace, invalid: :replace, replace: '')
    assert_equal encoded_subject, Account.current.tickets.last.subject
  end

  def test_create_iconv_fails_due_to_invalid_character_while_encoding_not_defined
    email_config1 = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    email_config2 = create_email_config(email: "freightw@#{@account.full_domain}")
    params = request_param(
      to_emails: [email_config1.to_email, email_config2.to_email],
      subject: "Hi...St. Paul\xE2%80%99s Cathedral...",
      headers: "text: Hi text\xF0\xA4\xAD\xA2.\xF0\xA4\xAD\xA2.\xF0\xA4\xAD,subject: Hi ICONV",
      text: " Hi text\xF0\xA4\xAD\xA2.\xF0\xA4\xAD\xA2.\xF0\xA4\xAD"
    )
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    account_wrap do
      post '/email', params.merge(authentication_params)
    end
    assert_response 200
    expected_subject = params[:subject].encode(Encoding::UTF_8, undef: :replace, invalid: :replace, replace: '')
    assert_equal expected_subject, Account.current.tickets.last.subject
  end

  def test_create_with_iconv_fails_while_defined_encoding
    email_config1 = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    email_config2 = create_email_config(email: "freightw@#{@account.full_domain}")
    charset_params = { text: 'iso-8859-8-i' }
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    params = request_param(
      to_emails: [email_config1.to_email, email_config2.to_email],
      subject: 'Hi Iconv fails',
      headers: "text: Hi text\xF0\xA4\xAD\xA2.\xF0\xA4\xAD\xA2.\xF0\xA4\xAD,subject: Hi ICONV",
      text: " ok \xF0\xA4\xAD\xA2.\xF0\xA4\xAD\xA2.\xF0\xA4\xAD",
      charsets: charset_params
    )
    account_wrap do
      post '/email', params.merge(authentication_params)
    end
    assert_response 200
    assert_equal params[:subject], Account.current.tickets.last.subject
    refute_equal params[:text], Account.current.tickets.last.description
  end

  def test_create_iconv_fails_with_text_wrong_encoding
    email_config1 = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    email_config2 = create_email_config(email: "freightw@#{@account.full_domain}")
    charset_params = { text: 'UTF-5' }
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    params = request_param(
      to_emails: [email_config1.to_email, email_config2.to_email],
      subject: 'Hi Iconv fails',
      headers: "text: Hi text\xF0\xA4\xAD\xA2.\xF0\xA4\xAD\xA2.\xF0\xA4\xAD,subject: Hi ICONV",
      text: 'wrong encoding',
      charsets: charset_params
    )
    account_wrap do
      post '/email', params.merge(authentication_params)
    end
    assert_response 200
    assert_equal params[:text], Account.current.tickets.last.description
  end

  def test_create_with_subject_quoted
    email_config1 = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    email_config2 = create_email_config(email: "freightw@#{@account.full_domain}")
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    params = request_param(
      to_emails: [email_config1.to_email, email_config2.to_email],
      subject: '=?UTF-8?B?0KHRgNC/0YHQutC4INGE0L7RgNGD0Lwg0YLRgNCw?= =?UTF-8?B?0LbQuCDQuNC30LHQvtGA0L3QuCDQvNCw0YLQtdGA0Lg=?= =?UTF-8?B?0ZjQsNC7INC4INC90LAg0ZvQuNGA0LjQu9C40YY=?= =?UTF-8?B?0LggLSBjaXJpbGFjZSB0ZXN0?=',
      headers: 'subject:=?UTF-8?B?0KHRgNC/0YHQutC4INGE0L7RgNGD0Lwg0YLRgNCw?= =?UTF-8?B?0LbQuCDQuNC30LHQvtGA0L3QuCDQvNCw0YLQtdGA0Lg=?= =?UTF-8?B?0ZjQsNC7INC4INC90LAg0ZvQuNGA0LjQu9C40YY=?= =?UTF-8?B?0LggLSBjaXJpbGFjZSB0ZXN0?='
    )
    account_wrap do
      post '/email', params.merge(authentication_params)
    end
    assert_response 200
    refute_equal params[:subject], Account.current.tickets.last.subject
  end

  def test_create_with_subject_encoded_with_replacement_character
    email_config1 = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    email_config2 = create_email_config(email: "freightw@#{@account.full_domain}")
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    params = request_param(
      to_emails: [email_config1.to_email, email_config2.to_email],
      subject: "Delivery Status Notification (Failure) \uFFFD",
      headers: "subject: Delivery Status Notification (Failure) \uFFFD"
    )
    account_wrap do
      post '/email', params.merge(authentication_params)
    end
    assert_response 200
    p Account.current.tickets.last.subject
    refute_equal params[:subject], Account.current.tickets.last.subject
  end

  def test_create_with_subject_without_charset
    email_config1 = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    email_config2 = create_email_config(email: "freightw@#{@account.full_domain}")
    params = request_param(
      to_emails: [email_config1.to_email, email_config2.to_email],
      charsets: { subject: nil, text: nil }
    )
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    account_wrap do
      post '/email', params.merge(authentication_params)
    end
    assert_response 200
    assert_equal params[:subject], Account.current.tickets.last.subject
  end

  def test_create_with_pod_redirection
    pod_name = Faker::Lorem.characters(10)
    stub_shard_mapping(pod_name, 'freightwatch.freshdesk.com')
    params = request_param(
      to_emails: ['freightwatchnlinfo@freightwatch.freshdesk.com'],
      charsets: { subject: nil, text: nil }
    )
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    account_wrap do
      post '/email', params.merge(authentication_params)
    end
    assert_response 302
    assert_equal response.header['X-Accel-Redirect'], "@pod_redirect_#{pod_name}"
  ensure
    unstub_shard_mapping
  end

  def test_create_with_subject_invalid_byte_sequence_in_utf_16
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    params = request_param(
      to_emails: ["freightwatchnlinfo@#{@account.full_domain}", "freightw@#{@account.full_domain}"],
      charsets: { subject: 'UTF-16' },
      headers: "subject: ...St. Paul\xE2%80%99s Cathedral...",
      subject: "...St. Paul\xE2%80%99s Cathedral..."
    )
    account_wrap do
      post '/email', params.merge(authentication_params)
    end
    assert_not_equal response.status, 200
  end

  def test_create_with_subject_encoded_exception
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    String.any_instance.stubs(:encode).raises(Exception)
    params = request_param(
      to_emails: ["freightwatchnlinfo@#{@account.full_domain}", "freightw@#{@account.full_domain}"],
      headers: "subject: ...St. Paul\xE2%80%99s Cathedral...",
      subject: "...St. Paul\xE2%80%99s Cathedral..."
    )
    account_wrap do
      post '/email', params.merge(authentication_params)
    end
    assert_not_equal response.status, 200
  ensure
    String.any_instance.unstub(:encode)
  end

  def test_validate_domain_with_blank_domain
    controller_params = { domain: '' }
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    account_wrap do
      post '/email/validate_domain', controller_params.merge(authentication_params)
    end
    assert_response 200
    match_json(validate_domain_hash(account: nil, shard_status: 404))
  end

  def test_validate_domain_without_email
    controller_params = { domain: @account.full_domain }
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    account_wrap do
      post '/email/validate_domain', controller_params.merge(authentication_params)
    end
    assert_response 200
    match_json(validate_domain_hash)
  end

  def test_validate_domain_without_blocked_user_email
    user = add_new_user(@account, blocked: 1)
    controller_params = { domain: @account.full_domain, email: user.email }
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    account_wrap do
      post '/email/validate_domain', controller_params.merge(authentication_params)
    end
    assert_response 200
    match_json(validate_domain_hash(user_status: 'blocked'))
  end

  def test_validate_domain_without_deleted_user_email
    user = add_new_user(@account, deleted: 1)
    controller_params = { domain: @account.full_domain, email: user.email }
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    post '/email/validate_domain', controller_params.merge(authentication_params)
    assert_response 200
    match_json(validate_domain_hash(user_status: 'deleted'))
  end

  def test_validate_domain_with_inactive_user_email
    user = add_new_user(@account, active: 0)
    User.any_instance.stubs(:valid_user?).returns(false)
    controller_params = { domain: @account.full_domain, email: user.email }
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    post '/email/validate_domain', controller_params.merge(authentication_params)
    assert_response 200
    match_json(validate_domain_hash(user_status: 'not_active'))
  ensure
    User.any_instance.unstub(:valid_user?)
  end

  def test_validate_domain_with_valid_user_email
    user = add_new_user(@account, active: 1)
    controller_params = { domain: @account.full_domain, email: user.email }
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    post '/email/validate_domain', controller_params.merge(authentication_params)
    assert_response 200
    match_json(validate_domain_hash(user_status: 'active'))
  end

  def test_validate_domain_with_shard_not_ok
    ShardMapping.any_instance.stubs(:ok?).returns(false)
    user = add_new_user(@account, active: 1)
    controller_params = { domain: @account.full_domain, email: user.email }
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    post '/email/validate_domain', controller_params.merge(authentication_params)
    assert_response 302
    assert_redirected_to '/DomainNotReady.html'
  ensure
    ShardMapping.any_instance.unstub(:ok?)
  end

  def test_account_details_success
    controller_params = { account_id: @account.id }
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    get '/email/account_details', controller_params.merge(authentication_params)
    assert_response 200
    match_json(account_details_hash(response.status == 200))
  end

  def test_account_details_without_user_name
    controller_params = { account_id: @account.id }
    authentication_params = { api_key: 'abcd' }
    get '/email/account_details', controller_params.merge(authentication_params)
    assert_response 404
  end

  def test_account_details_without_api_key
    controller_params = { account_id: @account.id }
    authentication_params = { username: 'freshdesk' }
    get '/email/account_details', controller_params.merge(authentication_params)
    assert_response 404
  end

  def test_account_details_success_with_authenticated_email_service_request
    controller_params = { account_id: @account.id }
    get '/email/account_details', controller_params, 'HTTP_AUTHORIZATION' => 'e7d6Gee5HkF6VjD7kIhpu7QmNkDeC6'
    assert_response 200
    match_json(account_details_hash(response.status == 200))
  end

  def test_account_details_with_false_authenticated_email_service_request
    controller_params = { account_id: @account.id }
    get '/email/account_details', controller_params, 'HTTP_AUTHORIZATION' => 'X'
    assert_response 404
  end

  def test_account_details_with_wrong_account_id
    controller_params = { account_id: Account.last.id + 1 }
    authentication_params = { username: 'freshdesk', api_key: 'abcd' }
    get '/email/account_details', controller_params.merge(authentication_params)
    assert_response 200
    match_json(account_details_hash(false))
  end

  private

    def request_param(to_emails: [], headers: '', subject: 'Hi encoded_subject', charsets: {}, html: '<div> Hi</div>', text: 'Hi')
      {
        html: html,
        subject: subject,
        text: text,
        from: 'padmashri@gmail.com',
        to: to_emails,
        envelope: envelope_params(from_email: 'padmashri@gmail.com', to_emails: to_emails),
        charsets: charset_params(charsets),
        headers: headers,
        attachments: '0'
      }
    end

    def envelope_params(from_email: '', to_emails: [])
      {
        from: from_email,
        to: to_emails
      }.to_json
    end

    def charset_params(text: 'UTF-8', html: 'UTF-8', subject: 'UTF-8', headers: 'UTF-8', from: 'UTF-8')
      {
        text: text,
        html: html,
        subject: subject,
        headers: headers,
        from: from
      }.to_json
    end

    def stub_shard_mapping(pod_info, domain)
      ShardMapping.stubs(:fetch_by_domain).returns(nil)
      ShardMapping.stubs(:fetch_by_domain).with(domain).returns(ShardMapping.new(pod_info: pod_info))
    end

    def unstub_shard_mapping
      ShardMapping.unstub(:fetch_by_domain)
    end

    def account_details_hash(success)
      {
        status: success ? 200 : 404,
        created_at: success ? @account.created_at : nil,
        account_domain: success ? @account.full_domain : nil,
        account_verified: success ? @account.verified? : nil,
        subscription_type: success ? @account.email_subscription_state : nil,
        mrr: success ? @account.subscription.cmrr : nil,
        signup_score: success ? @account.ehawk_reputation_score : nil,
        antispam_enabled: success ? true : nil
      }
    end

    def validate_domain_hash(account: @account, shard_status: nil, user_status: :not_found)
      shard_status ||= ShardMapping.lookup_with_domain(account.full_domain).status
      {
        domain_status: shard_status,
        created_at: account.try(:created_at),
        account_type: account.try(:email_subscription_state),
        account_id: account.try(:id),
        user_status: user_status
      }
    end

    def old_ui?
      true
    end
end
