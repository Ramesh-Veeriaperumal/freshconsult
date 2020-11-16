require_relative '../../../api/api_test_helper'
require Rails.root.join('test', 'api', 'helpers', 'test_case_methods.rb')
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('spec', 'support', 'email_configs_helper.rb')

class EmailServiceFlowTest < ActionDispatch::IntegrationTest
  include TestCaseMethods
  include UsersHelper
  include EmailConfigsHelper
  include Redis::OthersRedis

  # def test_new
  #   user = add_new_user
  #   email_config = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
  #   account_wrap do
  #     get '/email_service/new', request_param(from_email: user.email, to_emails: [email_config.to_email]), 'HTTP_AUTHORIZATION' => 'e7d6Gee5HkF6VjD7kIhpu7QmNkDeC6'
  #   end
  #   assert_response 200
  # end

  def test_create
    ticket_count = Account.current.tickets.count
    user = add_new_user
    email_config = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    account_wrap do
      post '/email_service', request_param(from_email: user.email, to_emails: [email_config.to_email]), 'HTTP_AUTHORIZATION' => 'e7d6Gee5HkF6VjD7kIhpu7QmNkDeC6'
    end
    assert_response 200
    assert_equal ticket_count + 1, Account.current.tickets.count
    assert_equal 'Auto responder has executed to session named BOREST2674', Account.current.tickets.last.subject
  end

  def test_create_with_shard_nil
    ticket_count = Account.current.tickets.count
    user = add_new_user
    email_config = create_email_config(email: 'freightwatchnlinfo@oyohomes.com')
    account_wrap do
      post '/email_service', request_param(from_email: user.email, to_emails: [email_config.to_email]), 'HTTP_AUTHORIZATION' => 'e7d6Gee5HkF6VjD7kIhpu7QmNkDeC6'
    end
    assert_response 200
    assert_equal ticket_count, Account.current.tickets.count
  end

  def test_create_with_shard_not_ok
    ticket_count = Account.current.tickets.count
    user = add_new_user
    ShardMapping.any_instance.stubs(:ok?).returns(false)
    email_config = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    account_wrap do
      post '/email_service', request_param(from_email: user.email, to_emails: [email_config.to_email]), 'HTTP_AUTHORIZATION' => 'e7d6Gee5HkF6VjD7kIhpu7QmNkDeC6'
    end
    assert_response 302
    assert_equal 'Your data is getting moved to a new datacenter.', response.body
    assert_equal ticket_count, Account.current.tickets.count
  ensure
    ShardMapping.any_instance.unstub(:ok?)
  end

  def test_create_with_shard_mapping_throw_exception
    ticket_count = Account.current.tickets.count
    user = add_new_user
    email_config = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    params = request_param(from_email: user.email, to_emails: [email_config.to_email]).tap { |param| param.delete(:from) }
    account_wrap do
      post '/email_service', params, 'HTTP_AUTHORIZATION' => 'e7d6Gee5HkF6VjD7kIhpu7QmNkDeC6'
    end
    assert_response 200
    assert_equal ticket_count + 1, Account.current.tickets.count
    assert_equal 'Auto responder has executed to session named BOREST2674', Account.current.tickets.last.subject
  end

  def test_create_with_user_blocked
    ticket_count = Account.current.tickets.count
    user = add_new_user(Account.current, blocked: 1)
    email_config = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    account_wrap do
      post '/email_service', request_param(from_email: user.email, to_emails: [email_config.to_email]), 'HTTP_AUTHORIZATION' => 'e7d6Gee5HkF6VjD7kIhpu7QmNkDeC6'
    end
    assert_response 200
    assert_equal ticket_count, Account.current.tickets.count
  end

  def test_create_with_new_user
    ticket_count = Account.current.tickets.count
    email_config = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    account_wrap do
      post '/email_service', request_param(from_email: 'abc@gmail.com', to_emails: [email_config.to_email]), 'HTTP_AUTHORIZATION' => 'e7d6Gee5HkF6VjD7kIhpu7QmNkDeC6'
    end
    assert_response 200
    assert_equal ticket_count + 1, Account.current.tickets.count
    assert_equal 'Auto responder has executed to session named BOREST2674', Account.current.tickets.last.subject
  end

  def test_create_with_account_absent_in_shard
    Account.stubs(:find_by_full_domain).returns(nil)
    ticket_count = Account.current.tickets.count
    email_config = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    account_wrap do
      post '/email_service', request_param(from_email: 'abc@gmail.com', to_emails: [email_config.to_email]), 'HTTP_AUTHORIZATION' => 'e7d6Gee5HkF6VjD7kIhpu7QmNkDeC6'
    end
    assert_response 200
    assert_equal ticket_count, Account.current.tickets.count
  ensure
    Account.unstub(:find_by_full_domain)
  end

  def test_create_with_account_not_active
    ticket_count = Account.current.tickets.count
    Account.any_instance.stubs(:allow_incoming_emails?).returns(false)
    email_config = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    account_wrap do
      post '/email_service', request_param(from_email: 'abc@gmail.com', to_emails: [email_config.to_email]), 'HTTP_AUTHORIZATION' => 'e7d6Gee5HkF6VjD7kIhpu7QmNkDeC6'
    end
    assert_response 200
    assert_equal ticket_count, Account.current.tickets.count
  ensure
    Account.any_instance.unstub(:allow_incoming_emails?)
  end

  def test_create_with_wrong_authentication
    user = add_new_user
    ticket_count = Account.current.tickets.count
    email_config = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    account_wrap do
      post '/email_service', request_param(from_email: user.email, to_emails: [email_config.to_email]), 'HTTP_AUTHORIZATION' => 'X'
    end
    assert_response 200
    assert_equal ticket_count, Account.current.tickets.count
  end

  def test_create_with_pod_redirection
    pod_name = Faker::Lorem.characters(10)
    stub_shard_mapping(pod_name, @account.full_domain)
    user = add_new_user
    email_config = create_email_config(email: "freightwatchnlinfo@#{@account.full_domain}")
    host!(nil)
    ticket_count = Account.current.tickets.count
    account_wrap do
      post '/email_service', request_param(from_email: user.email, to_emails: [email_config.to_email]), 'HTTP_AUTHORIZATION' => 'e7d6Gee5HkF6VjD7kIhpu7QmNkDeC6'
    end
    assert_response 302
    assert_equal response.header['X-Accel-Redirect'], "@pod_redirect_#{pod_name}"
    assert_equal ticket_count, Account.current.tickets.count
  ensure
    unstub_shard_mapping
  end

  def test_spam_threshold_reached
    Fdadmin::APICalls.stubs(:make_api_request_to_global).returns(true)
    Subscription.any_instance.stubs(:active?).returns(false)
    FreshdeskErrorsMailer.expects(:error_email).at_least_once
    account_wrap do
      post '/email_service/spam_threshold_reached', { account_id: Account.current.id }, 'HTTP_AUTHORIZATION' => 'e7d6Gee5HkF6VjD7kIhpu7QmNkDeC6'
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_present parsed_response['request_id']
    assert parsed_response['success']
    assert ismember?(SPAM_EMAIL_ACCOUNTS, Account.current.id)
  ensure
    Subscription.any_instance.unstub(:active?)
    Fdadmin::APICalls.unstub(:make_api_request_to_global)
  end

  def test_spam_threshold_reached_with_active_account
    Fdadmin::APICalls.stubs(:make_api_request_to_global).returns(true)
    Subscription.any_instance.stubs(:active?).returns(true)
    FreshdeskErrorsMailer.expects(:error_email).at_least_once
    account_wrap do
      post '/email_service/spam_threshold_reached', { account_id: Account.current.id }, 'HTTP_AUTHORIZATION' => 'e7d6Gee5HkF6VjD7kIhpu7QmNkDeC6'
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_present parsed_response['request_id']
    assert parsed_response['success']
    refute ismember?(SPAM_EMAIL_ACCOUNTS, Account.current.id)
  ensure
    Subscription.any_instance.unstub(:active?)
    Fdadmin::APICalls.unstub(:make_api_request_to_global)
  end

  def test_spam_threshold_reached_with_account_already_in_spam_email_account_list
    Fdadmin::APICalls.stubs(:make_api_request_to_global).returns(true)
    Subscription.any_instance.stubs(:active?).returns(false)
    FreshdeskErrorsMailer.expects(:error_email).never
    add_member_to_redis_set(SPAM_EMAIL_ACCOUNTS, Account.current.id)
    account_wrap do
      post '/email_service/spam_threshold_reached', { account_id: Account.current.id }, 'HTTP_AUTHORIZATION' => 'e7d6Gee5HkF6VjD7kIhpu7QmNkDeC6'
    end
    assert_response 200
    parsed_response = JSON.parse(response.body)
    assert_present parsed_response['request_id']
    assert parsed_response['success']
  ensure
    Subscription.any_instance.unstub(:active?)
    Fdadmin::APICalls.unstub(:make_api_request_to_global)
  end

  private

    def stub_shard_mapping(pod_info, domain)
      ShardMapping.stubs(:fetch_by_domain).returns(nil)
      ShardMapping.stubs(:fetch_by_domain).with(domain).returns(ShardMapping.new(pod_info: pod_info))
    end

    def unstub_shard_mapping
      ShardMapping.unstub(:fetch_by_domain)
    end

    def request_param(domain: Account.current.full_domain, from_email: '', to_emails: [])
      {
        attachments: '0',
        'attachment-info': {},
        subject: 'Auto responder has executed to session named BOREST2674',
        virus_scan_done: 'True',
        spam_info: spam_info,
        spam_done: 'True',
        x_account_id: Account.current.id.to_s,
        'content-ids': {},
        from: from_email,
        spam_check_done: 'True',
        headers: "Return-Path: <prvs=5772de0fd=GCConnect@goldencorral.net>\r\n
        MIME-Version: 1.0\r\nvirus_check_done: True\r\nFDSMTP.FROM: #{from_email}\r\n
        FDSMTP.ALL_RECIPIENTS: [support@goldencorralhelp.freshdesk.com\"]\r\n
        FDSMTP.RECIPIENTS_PENDING: [\"support@goldencorralhelp.freshdesk.com\"]\r\nX-EMAIL-SOURCE: SMTP\r\nX-IS-SECURE: true\r\n
        X-RECEIVED-AT: 2020-11-11T03:48:15.693+0000\r\nX-QUEUED-AT: 2020-11-11T03:48:15.854+0000\r\n
        X-MAIL-CREATED-AT: 2020-11-11T03:48:15.000+0000\r\nFD.APPLICATION.ID: 1\r\nX-ACCOUNT-ID: 1629428\r\n
        Received: from mail.goldencorral.net (EHLO ironportemail.goldencorral.net)
        ([174.46.136.140])\r\n          by mxa.freshdesk.com (Freshworks SMTP Server)
        with ESMTP ID -232360696.1\r\n          for <support@goldencorralhelp.freshdesk.com>;\r\n          Wed, 11 Nov 2020 03:48:15 +0000 (UTC)\r\n
        IronPort-SDR: JYxKqVA9HCYDQbGsPMz+VtcD/qE0uPh3jclvGcxIjlf02JJYdXpc1wyNrNZHcWP455JlSa9rpl\r\n
        yNMmtxoyL6wfju0lkb9zM8brIE9B2gjIjg6kRK1RjCfZXu9JXNMsXhHjcX3H1CE1LbJp0jbTD0\r\n pqodMwMT7jDWNPuXfzMQS5FgpUHc86FkkvFH/Cj0gfNFKmclH2DGiVweDB5NMrfghNP1ldSt0K\r\n
        SrQMsECBUROWxw6D6n5q4mfymVJWFM7cfvYIk9t0QqvByBb2BvxJFjkIF46+IDGGyXDqky0KWC\r\n
        BH4=\r\nX-IronPort-AV: E=Sophos;i=\"5.77,468,1596513600\"; \r\n
        d=\"scan'208\";a=\"21090988\"\r\nReceived: from exchange2013.goldencorral.net ([192.168.118.60])\r\n
        by ironportemail.goldencorral.net with ESMTP/TLS/ECDHE-RSA-AES256-SHA384; 10 Nov 2020 22:48:15 -0500\r\n
        Received: from EXCHANGE2013.goldencorral.net (192.168.118.60) by\r\n
        exchange2013.goldencorral.net (192.168.118.60) with Microsoft SMTP Server\r\n
        (TLS) id 15.0.1497.2; Tue, 10 Nov 2020 22:48:15 -0500\r\n
        Received: from GC-CONNECT (192.168.118.112) by EXCHANGE2013.goldencorral.net\r\n
        (192.168.118.60) with Microsoft SMTP Server id 15.0.1497.2 via Frontend\r\n
        Transport; Tue, 10 Nov 2020 22:48:15 -0500\r\n
        From: <#{from_email}>\r\n
        To: <openticket@#{domain}>\r\n
        Date: Tue, 10 Nov 2020 22:48:15 -0500\r\n
        Subject: Auto responder has executed to session named BOREST2674\r\n
        Content-Type: text/plain; charset=\"us-ascii\"\r\n
        Message-ID: <c41b35a1bbc44a21bbf4cc9561edce26@EXCHANGE2013.goldencorral.net>\r\nContent-Transfer-Encoding: quoted-printable\r\n",
        attachments_base_paths: {},
        internal_date: 'Tue, 10 Nov 2020 22:48:15 -0500',
        auto_link_done: 'False',
        envelope: envelope_params(from_email: from_email, to_emails: to_emails),
        to: "<openticket@#{domain}>",
        virus_check_done: 'True',
        charsets: charset_params
      }
    end

    def spam_info
      {
        status: 200,
        score: 0.2,
        required_score: 6,
        is_spam: false,
        sender_score: 0,
        rules: ['TO_DN_NONE', 'ENVFROM_PRVS', 'RCVD_NO_TLS_LAST', 'RCVD_COUNT_THREE', 'MIME_GOOD', 'MID_RHS_MATCH_FROMTLD', 'ARC_NA', 'RCPT_COUNT_ONE', 'TO_DOM_EQ_FROM_DOM', 'DMARC_NA', 'FROM_NO_DN', 'KAM_NUMSUBJECT', 'FROM_NEQ_ENVFROM', 'R_DKIM_NA', 'MIME_TRACE']
      }.to_json
    end

    def envelope_params(domain: Account.current.full_domain, from_email: '', to_emails: [])
      {
        from: from_email,
        to: to_emails
      }.to_json
    end

    def charset_params
      {
        text: 'UTF-8',
        html: 'UTF-8',
        subject: 'UTF-8',
        headers: 'UTF-8',
        from: 'UTF-8'
      }.to_json
    end
end
