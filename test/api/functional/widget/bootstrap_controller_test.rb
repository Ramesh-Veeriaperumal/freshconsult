require_relative '../../test_helper'
module Widget
  class BootstrapControllerTest < ActionController::TestCase
    include HelpWidgetsTestHelper
    include AgentsTestHelper

    def setup
      super
      before_all
    end

    def before_all
      @widget = create_widget
      @request.env['HTTP_X_WIDGET_ID'] = @widget.id
      @client_id = UUIDTools::UUID.timestamp_create.hexdigest
      @request.env['HTTP_X_CLIENT_ID'] = @client_id
      @account.launch :help_widget
      @account.launch :help_widget_login
      @secret_key = SecureRandom.hex
      @account.stubs(:help_widget_secret).returns(@secret_key)
    end

    def teardown
      @account.rollback :help_widget_login
      @account.unstub(:help_widget_secret)
    end

    def test_widget_bootstrap_with_new_user
      timestamp = Time.now.utc.iso8601
      User.any_instance.stubs(:agent?).returns(false)
      auth_token = JWT.encode({ name: 'Padmashri',
                                email: 'praaji.longbottom@freshworks.com',
                                timestamp: timestamp }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 200
      id = JSON.parse(@response.body)['user']['id']
      user = @account.users.find(id)
      parsed_time = Time.iso8601(timestamp.to_datetime.to_s) && Time.zone.parse(timestamp.to_s)
      expire_at = (parsed_time + 2.hours).strftime('%Y-%m-%dT%H:%M:%SZ')
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header.include?('_helpkit_session')
      assert_equal User.current.id, user.id
    ensure
      User.any_instance.unstub(:agent?)
    end

    def test_widget_bootstrap_with_existing_user
      user = @account.users.first
      timestamp = Time.now.utc.iso8601
      User.any_instance.stubs(:agent?).returns(false)
      auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 200
      id = JSON.parse(@response.body)['user']['id']
      parsed_time = Time.iso8601(timestamp.to_datetime.to_s) && Time.zone.parse(timestamp.to_s)
      expire_at = (parsed_time + 2.hours).strftime('%Y-%m-%dT%H:%M:%SZ')
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header['Set-Cookie'].include?('_helpkit_session')
      assert_equal user.id, id
      assert_equal User.current.id, user.id
    ensure
      User.any_instance.unstub(:agent?)
    end

    def test_widget_bootstrap_with_existing_user_name_changed
      user = @account.users.first
      user_name = user.name
      User.any_instance.stubs(:agent?).returns(false)
      timestamp = Time.now.utc.iso8601
      auth_token = JWT.encode({ name: 'JohnMichy Steapo Kan',
                                email: user.email,
                                timestamp: timestamp }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 200
      id = JSON.parse(@response.body)['user']['id']
      parsed_time = Time.iso8601(timestamp.to_datetime.to_s) && Time.zone.parse(timestamp.to_s)
      expire_at = (parsed_time + 2.hours).strftime('%Y-%m-%dT%H:%M:%SZ')
      user.reload
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header['Set-Cookie'].include?('_helpkit_session')
      assert_equal user.id, id
      assert_equal User.current.id, user.id
      assert_equal User.current.name, 'JohnMichy Steapo Kan'
      refute_equal User.current.name, user_name
    ensure
      User.any_instance.unstub(:agent?)
    end

    def test_widget_bootstrap_with_existing_user_provided_secondary_email
      user = @account.users.first
      User.any_instance.stubs(:agent?).returns(false)
      user_email = user.user_emails.new
      user_email.email = 'oppo@samsung.com'
      user_email.save
      timestamp = Time.now.utc.iso8601
      auth_token = JWT.encode({ name: user.name, email: user_email.email, timestamp: timestamp }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 200
      id = JSON.parse(@response.body)['user']['id']
      parsed_time = Time.iso8601(timestamp.to_datetime.to_s) && Time.zone.parse(timestamp.to_s)
      expire_at = (parsed_time + 2.hours).strftime('%Y-%m-%dT%H:%M:%SZ')
      match_json(widget_bootstrap_pattern(user, expire_at, user_email.email))
      refute @response.header['Set-Cookie'].include?('_helpkit_session')
      assert_equal user.id, id
      assert_equal User.current.id, user.id
    ensure
      User.any_instance.unstub(:agent?)
    end

    def test_widget_bootstrap_with_negative_zone_time_stamp
      user = @account.users.first
      User.any_instance.stubs(:agent?).returns(false)
      zone = ActiveSupport::TimeZone[-7].name
      timestamp = Time.now.in_time_zone(zone).utc.iso8601
      auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 200
      id = JSON.parse(@response.body)['user']['id']
      parsed_time = (Time.iso8601(timestamp.to_datetime.to_s) && Time.zone.parse(timestamp.to_s))
      expire_at = (parsed_time + 2.hours).strftime('%Y-%m-%dT%H:%M:%SZ')
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header['Set-Cookie'].include?('_helpkit_session')
      assert_equal user.id, id
      assert_equal User.current.id, user.id
    ensure
      User.any_instance.unstub(:agent?)
    end

    def test_widget_bootstrap_with_additional_user_params
      timestamp = Time.now.utc.iso8601
      User.any_instance.stubs(:agent?).returns(false)
      auth_token = JWT.encode({ name: 'PariStepen',
                                email: 'paristepen.harry@freshworks.com',
                                phone: '9880990122',
                                timestamp: timestamp }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 200
      id = JSON.parse(@response.body)['user']['id']
      user = @account.users.find(id)
      parsed_time = Time.iso8601(timestamp.to_datetime.to_s) && Time.zone.parse(timestamp.to_s)
      expire_at = (parsed_time + 2.hours).strftime('%Y-%m-%dT%H:%M:%SZ')
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header['Set-Cookie'].include?('_helpkit_session')
      assert_equal User.current.id, user.id
      assert_nil @account.users.find(id).phone
    ensure
      User.any_instance.unstub(:agent?)
    end

    def test_widget_bootstrap_with_restricted_helpdesk
      @account.launch(:restricted_helpdesk)
      User.any_instance.stubs(:agent?).returns(false)
      @account.features.restricted_helpdesk.create
      @account.helpdesk_permissible_domains.create(domain: 'restrictedhelpdesk.com')
      timestamp = Time.now.utc.iso8601
      auth_token = JWT.encode({ name: 'Padmashri',
                                email: 'praaji.longbottom@restrictedhelpdesk.com',
                                timestamp: timestamp }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 200
      id = JSON.parse(@response.body)['user']['id']
      user = @account.users.find(id)
      parsed_time = Time.iso8601(timestamp.to_datetime.to_s) && Time.zone.parse(timestamp.to_s)
      expire_at = (parsed_time + 2.hours).strftime('%Y-%m-%dT%H:%M:%SZ')
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header.include?('_helpkit_session')
      assert_equal User.current.id, user.id
    ensure
      User.any_instance.unstub(:agent?)
      @account.features.restricted_helpdesk.destroy
      @account.rollback(:restricted_helpdesk)
    end

    def test_widget_bootstrap_with_user_being_agent
      user = add_agent(@account, role: Role.find_by_name('Agent').id)
      timestamp = Time.now.utc.iso8601
      auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: timestamp }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 200
      id = JSON.parse(@response.body)['user']['id']
      parsed_time = Time.iso8601(timestamp.to_datetime.to_s) && Time.zone.parse(timestamp.to_s)
      expire_at = (parsed_time + 2.hours).strftime('%Y-%m-%dT%H:%M:%SZ')
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header['Set-Cookie'].include?('_helpkit_session')
      assert_equal user.id, id
      assert_equal User.current.id, user.id
    end

    def test_widget_bootstap_without_token
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json(request_error_pattern('x_widget_auth_required'))
    end

    def test_widget_boostrap_with_user_blocked
      user = @account.users.first
      User.any_instance.stubs(:blocked?).returns(true)
      User.any_instance.stubs(:agent?).returns(false)
      auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: Time.now.utc.iso8601 }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 403
      match_json(request_error_pattern('invalid_user', id: user.id, name: user.name))
    ensure
      User.any_instance.unstub(:blocked?)
      User.any_instance.unstub(:agent?)
    end

    def test_widget_boostrap_with_user_deleted
      user = @account.users.first
      User.any_instance.stubs(:deleted?).returns(true)
      User.any_instance.stubs(:agent?).returns(false)
      auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: Time.now.utc.iso8601 }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 403
      match_json(request_error_pattern('invalid_user', id: user.id, name: user.name))
    ensure
      User.any_instance.unstub(:deleted?)
      User.any_instance.unstub(:agent?)
    end

    def test_widget_boostrap_with_spam_user
      user = @account.users.first
      User.any_instance.stubs(:spam?).returns(true)
      User.any_instance.stubs(:agent?).returns(false)
      auth_token = JWT.encode({ name: user.name, email: user.email, timestamp: Time.now.utc.iso8601 }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 403
      match_json(request_error_pattern('invalid_user', id: user.id, name: user.name))
    ensure
      User.any_instance.unstub(:spam?)
      User.any_instance.unstub(:agent?)
    end

    def test_widget_bootstrap_without_timestamp
      auth_token = JWT.encode({ name: 'Sara George',
                                email: 'sarageorge.hmm@freshworks.com' }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('payload', 'timestamp', 'Field is missing/blank', code: 'missing_field')])
    end

    def test_widget_bootstrap_with_timestamp_empty
      auth_token = JWT.encode({ name: 'Sara George',
                                email: 'sarageorge.hmm@freshworks.com',
                                timestamp: '' }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('payload', 'timestamp', 'Field is missing/blank', code: 'invalid_value')])
    end

    def test_widget_bootstrap_without_email
      auth_token = JWT.encode({ name: 'Padmashri',
                                timestamp: Time.now.utc.iso8601 }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json('description' => 'Validation failed',
                 'errors' => [bad_request_error_pattern_with_nested_field('payload', 'email', 'Field is missing/blank', code: 'missing_field')])
    end

    def test_widget_bootstrap_with_email_empty
      auth_token = JWT.encode({ name: 'Padmashri',
                                email: '',
                                timestamp: Time.now.utc.iso8601 }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json('description' => 'Validation failed',
                 'errors' => [bad_request_error_pattern_with_nested_field('payload', 'email', 'Field is missing/blank', code: 'invalid_value')])
    end

    def test_widget_bootstrap_without_name
      auth_token = JWT.encode({ email: 'sarageorge.hmm@freshworks.com',
                                timestamp: Time.now.utc.iso8601 }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json('description' => 'Validation failed',
                 'errors' => [bad_request_error_pattern_with_nested_field('payload', 'name', 'Field is missing/blank', code: 'missing_field')])
    end

    def test_widget_bootstrap_with_name_empty
      auth_token = JWT.encode({ name: '',
                                email: 'sarageorge.hmm@freshworks.com',
                                timestamp: Time.now.utc.iso8601 }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json('description' => 'Validation failed', 'errors' => [bad_request_error_pattern_with_nested_field('payload', 'name', 'Field is missing/blank', code: 'invalid_value')])
    end

    def test_widget_bootstrap_with_wrong_secret_key_encoding
      auth_token = JWT.encode({ name: 'PariStepen',
                                email: 'paristepen.harry@freshworks.com',
                                timestamp: Time.now.utc.iso8601 }, @secret_key + 'wrong')
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 401
    end

    def test_widget_bootstrap_timestamp_outbound
      auth_token = JWT.encode({ name: 'Sangira',
                                email: 'sangira.molphoy@freshworks.com',
                                timestamp: 3.hours.ago.utc.iso8601 }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 401
      match_json('description' => 'Validation failed',
                 'errors' => [bad_request_error_pattern('timestamp', 'invalid_timestamp', code: 'unauthorized')])
    end

    def test_widget_bootstrap_timestamp_upbound
      auth_token = JWT.encode({ name: 'Sangira',
                                email: 'sangira.molphoy@freshworks.com',
                                timestamp: 3.hours.since.utc.iso8601 }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 401
      match_json('description' => 'Validation failed',
                 'errors' => [bad_request_error_pattern('timestamp', 'invalid_timestamp', code: 'unauthorized')])
    end

    def test_widget_bootstrap_timestamp_without_plus_minus_in_zone
      auth_token = JWT.encode({ name: 'Sangira',
                                email: 'sangira.molphoy@freshworks.com',
                                timestamp: '2019-10-26T13:46:03 05:30' }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json([bad_request_error_pattern('timestamp', 'invalid_timestamp', code: 'invalid_value')])
    end

    def test_widget_bootstrap_timestamp_with_invalid_second
      auth_token = JWT.encode({ name: 'Sangira',
                                email: 'sangira.molphoy@freshworks.com',
                                timestamp: '2019-10-26T13:46:93+05:30' }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json([bad_request_error_pattern('timestamp', 'invalid_timestamp', code: 'invalid_value')])
    end

    def test_widget_bootstrap_timestamp_with_invalid_minute
      auth_token = JWT.encode({ name: 'sangira',
                                email: 'sangira.molphoy@freshworks.com',
                                timestamp: '2019-10-26T13:66:03+05:30' }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json([bad_request_error_pattern('timestamp', 'invalid_timestamp', code: 'invalid_value')])
    end

    def test_widget_bootstrap_timestamp_with_invalid_date
      auth_token = JWT.encode({ name: 'sangira',
                                email: 'sangira.molphoy@freshworks.com',
                                timestamp: '2019-10-66T13:46:03+05:30' }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json([bad_request_error_pattern('timestamp', 'invalid_timestamp', code: 'invalid_value')])
    end

    def test_widget_bootstrap_timestamp_non_utc
      auth_token = JWT.encode({ name: 'sangira',
                                email: 'sangira.molphoy@freshworks.com',
                                timestamp: '2019-10-26T13:46:03+05:30' }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json([bad_request_error_pattern('timestamp', 'timestamp must be in UTC', code: 'invalid_value')])
    end

    def test_widget_bootstrap_invalid_email
      User.stubs(:current).returns(nil)
      auth_token = JWT.encode({ name: 'Opriaa',
                                email: 'opria',
                                timestamp: Time.now.utc.iso8601 }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('payload', 'email', "It should be in the 'valid email address' format", code: 'invalid_value')])
    ensure
      User.unstub(:current)
    end

    def test_widget_bootstrap_signup_failed
      User.stubs(:current).returns(nil)
      auth_token = JWT.encode({ name: 'Opriaa',
                                email: 'opria.ron@freshworks.com',
                                timestamp: Time.now.utc.iso8601 }, @secret_key)
      User.any_instance.stubs(:signup!).returns(false)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 403
      match_json('code' => 'unable_to_perform', 'message' => 'Unable to perform')
    ensure
      User.any_instance.unstub(:signup!)
      User.unstub(:current)
    end

    def test_widget_bootstrap_restricted_helpdesk_invalid_domain
      @account.launch(:restricted_helpdesk)
      @account.features.restricted_helpdesk.create
      @account.helpdesk_permissible_domains.create(domain: 'restrictedhelpdesk.com')
      timestamp = Time.now.utc.iso8601
      auth_token = JWT.encode({ name: 'Praaji',
                                email: 'praaji.longbottom@helpdesk.com',
                                timestamp: timestamp }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 403
      match_json(request_error_pattern('action_restricted', action: 'login', reason: 'domain/user is restricted in Admin'))
    ensure
      @account.features.restricted_helpdesk.destroy
      @account.rollback(:restricted_helpdesk)
    end

    def test_widget_bootstrap_without_help_widget_login_feature
      @account.rollback(:help_widget_login)
      timestamp = Time.now.utc.iso8601
      auth_token = JWT.encode({ name: 'Padmashri',
                                email: 'praaji.longbottom@freshworks.com',
                                timestamp: timestamp }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 403
      match_json(request_error_pattern(:require_feature, feature: 'Help Widget Login'))
    ensure
      @account.launch(:help_widget)
    end

    def test_widget_bootstrap_without_help_widget_enabled
      @account.stubs(:help_widget_enabled?).returns(false)
      timestamp = Time.now.utc.iso8601
      auth_token = JWT.encode({ name: 'Padmashri',
                                email: 'praaji.longbottom@freshworks.com',
                                timestamp: timestamp }, @secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 403
      match_json(request_error_pattern(:require_feature, feature: :help_widget))
    ensure
      @account.unstub(:help_widget_enabled?)
    end
  end
end
