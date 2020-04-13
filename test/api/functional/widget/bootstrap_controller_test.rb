require_relative '../../test_helper'
module Widget
  class BootstrapControllerTest < ActionController::TestCase
    include HelpWidgetsTestHelper
    include AgentsTestHelper
    include UsersHelper

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
    end

    def teardown
      @widget.try(:destroy)
      super
      unset_login_support
    end

    def test_widget_bootstrap_with_new_user
      resultant_exp = set_user_login_headers
      get :index, construct_params(version: 'widget')
      assert_response 200
      expire_at = Time.at(resultant_exp).utc.strftime(JWTAuthentication::EXPIRE_AT_FORMAT)
      id = JSON.parse(@response.body)['user']['id']
      user = @account.users.find(id)
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header.include?('_helpkit_session')
      assert_equal User.current.id, user.id
      assert user.active
    ensure
      user.destroy
    end

    def test_widget_bootstrap_with_existing_user
      user = add_new_user(@account)
      resultant_exp = set_user_login_headers(name: user.name, email: user.email)
      get :index, construct_params(version: 'widget')
      assert_response 200
      expire_at = Time.at(resultant_exp).utc.strftime(JWTAuthentication::EXPIRE_AT_FORMAT)
      id = JSON.parse(@response.body)['user']['id']
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header['Set-Cookie'].include?('_helpkit_session')
      assert_equal user.id, id
      assert_equal User.current.id, user.id
      user.reload
      assert user.active
    ensure
      user.destroy
    end

    def test_widget_bootstrap_with_existing_user_name_changed
      user = add_new_user(@account)
      user_name = user.name
      resultant_exp = set_user_login_headers(name: 'JohnMichy Steapo Kan', email: user.email)
      get :index, construct_params(version: 'widget')
      assert_response 200
      expire_at = Time.at(resultant_exp).utc.strftime(JWTAuthentication::EXPIRE_AT_FORMAT)
      id = JSON.parse(@response.body)['user']['id']
      user.reload
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header['Set-Cookie'].include?('_helpkit_session')
      assert_equal user.id, id
      assert_equal User.current.id, user.id
      assert_equal User.current.name, 'JohnMichy Steapo Kan'
      refute_equal User.current.name, user_name
      assert user.active
    ensure
      user.destroy
    end

    def test_widget_bootstrap_with_existing_user_provided_secondary_email
      user = add_new_user(@account)
      user_email = user.user_emails.new
      user_email.email = 'oppo@samsung.com'
      user_email.save
      resultant_exp = set_user_login_headers(name: user.name, email: user_email.email)
      get :index, construct_params(version: 'widget')
      assert_response 200
      expire_at = Time.at(resultant_exp).utc.strftime(JWTAuthentication::EXPIRE_AT_FORMAT)
      id = JSON.parse(@response.body)['user']['id']
      match_json(widget_bootstrap_pattern(user, expire_at, user_email.email))
      refute @response.header['Set-Cookie'].include?('_helpkit_session')
      assert_equal user.id, id
      assert_equal User.current.id, user.id
      user.reload
      assert user.active
    ensure
      user.destroy
    end

    def test_widget_bootstrap_with_non_active_user
      user = @account.users.new(name: 'Oppo', email: 'oppo@gmail.com')
      user.active = false
      user.save
      resultant_exp = set_user_login_headers(name: user.name, email: user.email)
      get :index, construct_params(version: 'widget')
      assert_response 200
      expire_at = Time.at(resultant_exp).utc.strftime(JWTAuthentication::EXPIRE_AT_FORMAT)
      id = JSON.parse(@response.body)['user']['id']
      match_json(widget_bootstrap_pattern(user, expire_at, user.email))
      refute @response.header['Set-Cookie'].include?('_helpkit_session')
      assert_equal user.id, id
      assert_equal User.current.id, user.id
      user.reload
      assert user.active
    end

    def test_widget_bootstrap_with_negative_zone_time_stamp
      user = add_new_user(@account)
      zone = ActiveSupport::TimeZone[-7].name
      exp = Time.now.in_time_zone(zone) + 1.hour
      resultant_exp = set_user_login_headers(name: user.name, email: user.email, exp: exp.to_i)
      get :index, construct_params(version: 'widget')
      assert_response 200
      expire_at = Time.at(resultant_exp).utc.strftime(JWTAuthentication::EXPIRE_AT_FORMAT)
      id = JSON.parse(@response.body)['user']['id']
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header['Set-Cookie'].include?('_helpkit_session')
      assert_equal user.id, id
      assert_equal User.current.id, user.id
      assert user.active
    ensure
      user.destroy
    end

    def test_widget_bootstrap_with_additional_user_params
      resultant_exp = set_user_login_headers(additional_payload: { phone: '9880990122' })
      get :index, construct_params(version: 'widget')
      assert_response 200
      expire_at = Time.at(resultant_exp).utc.strftime(JWTAuthentication::EXPIRE_AT_FORMAT)
      id = JSON.parse(@response.body)['user']['id']
      user = @account.users.find(id)
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header['Set-Cookie'].include?('_helpkit_session')
      assert_equal User.current.id, user.id
      assert_nil @account.users.find(id).phone
      assert user.active
    end

    def test_widget_bootstrap_with_additional_jwt_claims
      resultant_exp = set_user_login_headers(additional_payload: { iat: Time.now.to_i })
      get :index, construct_params(version: 'widget')
      assert_response 200
      expire_at = Time.at(resultant_exp).utc.strftime(JWTAuthentication::EXPIRE_AT_FORMAT)
      id = JSON.parse(@response.body)['user']['id']
      user = @account.users.find(id)
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header['Set-Cookie'].include?('_helpkit_session')
      assert_equal User.current.id, user.id
      assert_nil @account.users.find(id).phone
      assert user.active
    end

    def test_widget_bootstrap_with_iat_unchecked
      resultant_exp = set_user_login_headers(additional_payload: { iat: (Time.now.utc + 2.hours).to_i })
      get :index, construct_params(version: 'widget')
      assert_response 200
      expire_at = Time.at(resultant_exp).utc.strftime(JWTAuthentication::EXPIRE_AT_FORMAT)
      id = JSON.parse(@response.body)['user']['id']
      user = @account.users.find(id)
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header['Set-Cookie'].include?('_helpkit_session')
      assert_equal User.current.id, user.id
      assert_nil @account.users.find(id).phone
      assert user.active
    end

    def test_widget_bootstrap_with_restricted_helpdesk
      @account.launch(:restricted_helpdesk)
      @account.features.restricted_helpdesk.create
      @account.helpdesk_permissible_domains.create(domain: 'restrictedhelpdesk.com')
      resultant_exp = set_user_login_headers(name: 'Padmashri', email: 'praaji.longbottom@restrictedhelpdesk.com')
      get :index, construct_params(version: 'widget')
      assert_response 200
      expire_at = Time.at(resultant_exp).utc.strftime(JWTAuthentication::EXPIRE_AT_FORMAT)
      id = JSON.parse(@response.body)['user']['id']
      user = @account.users.find(id)
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header.include?('_helpkit_session')
      assert_equal User.current.id, user.id
      assert user.active
    ensure
      @account.features.restricted_helpdesk.destroy
      @account.rollback(:restricted_helpdesk)
    end

    def test_widget_bootstrap_with_user_being_agent
      user = add_agent(@account, role: Role.find_by_name('Agent').id)
      resultant_exp = set_user_login_headers(name: user.name, email: user.email)
      get :index, construct_params(version: 'widget')
      assert_response 200
      expire_at = Time.at(resultant_exp).utc.strftime(JWTAuthentication::EXPIRE_AT_FORMAT)
      id = JSON.parse(@response.body)['user']['id']
      match_json(widget_bootstrap_pattern(user, expire_at))
      refute @response.header['Set-Cookie'].include?('_helpkit_session')
      assert_equal user.id, id
      assert_equal User.current.id, user.id
      assert user.active
    end

    def test_widget_bootstap_without_token
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json(request_error_pattern('x_widget_auth_required'))
    end

    def test_widget_boostrap_with_user_blocked
      user = add_new_user(@account)
      User.any_instance.stubs(:blocked?).returns(true)
      set_user_login_headers(name: user.name, email: user.email)
      get :index, construct_params(version: 'widget')
      assert_response 403
      match_json(request_error_pattern('invalid_user', id: user.id, name: user.name))
    ensure
      User.any_instance.unstub(:blocked?)
      user.destroy
    end

    def test_widget_boostrap_with_user_deleted
      user = add_new_user(@account)
      User.any_instance.stubs(:deleted?).returns(true)
      set_user_login_headers(name: user.name, email: user.email)
      get :index, construct_params(version: 'widget')
      assert_response 403
      match_json(request_error_pattern('invalid_user', id: user.id, name: user.name))
    ensure
      User.any_instance.unstub(:deleted?)
      user.destroy
    end

    def test_widget_boostrap_with_spam_user
      user = add_new_user(@account)
      User.any_instance.stubs(:spam?).returns(true)
      set_user_login_headers(name: user.name, email: user.email)
      get :index, construct_params(version: 'widget')
      assert_response 403
      match_json(request_error_pattern('invalid_user', id: user.id, name: user.name))
    ensure
      User.any_instance.unstub(:spam?)
      user.destroy
    end

    def test_widget_boostrap_with_user_blocked_user_name_changed
      user = add_new_user(@account)
      name = user.name
      User.any_instance.stubs(:blocked?).returns(true)
      set_user_login_headers(name: "#{name} RANA", email: user.email)
      get :index, construct_params(version: 'widget')
      assert_response 403
      match_json(request_error_pattern('invalid_user', id: user.id, name: user.name))
      user.reload
      assert_equal user.name, name
    ensure
      User.any_instance.unstub(:blocked?)
      user.destroy
    end

    def test_widget_bootstrap_without_exp
      set_user_login_headers(name: 'Sara George', email: 'sarageorge.hmm@freshworks.com', additional_operations: { remove_key: :exp })
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('payload', 'exp', 'Field is missing/blank', code: 'missing_field')])
    end

    def test_widget_bootstrap_with_exp_empty
      set_user_login_headers(exp: '')
      get :index, construct_params(version: 'widget')
      assert_response 401
      match_json('description' => 'Validation failed',
                 'errors' => [bad_request_error_pattern('token', 'Signature has expired', code: 'unauthorized')])
    end

    def test_widget_bootstrap_with_exp_negative
      secret_key = SecureRandom.hex
      @account.stubs(:help_widget_secret).returns(secret_key)
      auth_token = JWT.encode({ name: 'Padmashri',
                                email: 'praaji.longbottom@freshworks.com',
                                exp: -12 }, secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 401
      match_json('description' => 'Validation failed',
                 'errors' => [bad_request_error_pattern('token', 'Signature has expired', code: 'unauthorized')])
    ensure
      @account.unstub(:help_widget_secret)
    end

    def test_widget_bootstrap_with_expired_time
      secret_key = SecureRandom.hex
      @account.stubs(:help_widget_secret).returns(secret_key)
      auth_token = JWT.encode({ name: 'Padmashri',
                                email: 'praaji.longbottom@freshworks.com',
                                exp: (Time.now.utc - 4.hours).to_i }, secret_key)
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 401
      match_json('description' => 'Validation failed',
                 'errors' => [bad_request_error_pattern('token', 'Signature has expired', code: 'unauthorized')])
    ensure
      @account.unstub(:help_widget_secret)
    end

    def test_widget_bootstrap_without_email
      set_user_login_headers(additional_operations: { remove_key: :email })
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json('description' => 'Validation failed',
                 'errors' => [bad_request_error_pattern_with_nested_field('payload', 'email', 'Field is missing/blank', code: 'missing_field')])
    end

    def test_widget_bootstrap_with_string_exp
      set_user_login_headers(exp: 'ahai')
      get :index, construct_params(version: 'widget')
      assert_response 401
      match_json('description' => 'Validation failed',
                 'errors' => [bad_request_error_pattern('token', 'Signature has expired', code: 'unauthorized')])
    end

    def test_widget_bootstrap_with_email_empty
      set_user_login_headers(email: '')
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json('description' => 'Validation failed',
                 'errors' => [bad_request_error_pattern_with_nested_field('payload', 'email', 'Field is missing/blank', code: 'invalid_value')])
    end

    def test_widget_bootstrap_without_name
      set_user_login_headers(additional_operations: { remove_key: :name })
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json('description' => 'Validation failed',
                 'errors' => [bad_request_error_pattern_with_nested_field('payload', 'name', 'Field is missing/blank', code: 'missing_field')])
    end

    def test_widget_bootstrap_with_name_empty
      set_user_login_headers(name: '')
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json('description' => 'Validation failed', 'errors' => [bad_request_error_pattern_with_nested_field('payload', 'name', 'Field is missing/blank', code: 'invalid_value')])
    end

    def test_widget_bootstrap_with_wrong_secret_key_encoding
      secret_key = SecureRandom.hex
      @account.stubs(:help_widget_secret).returns(secret_key)
      exp = (Time.now.utc + 2.hours).to_i
      payload = { name: 'Padmashri',
                  email: 'praaji.longbottom@freshworks.com',
                  exp: exp }
      auth_token = JWT.encode(payload, 'wrong')
      @request.env['HTTP_X_WIDGET_AUTH'] = auth_token
      get :index, construct_params(version: 'widget')
      assert_response 401
    ensure
      @account.unstub(:help_widget_secret)
    end

    def test_widget_bootstrap_with_exp_greater_than_max
      exp = (Time.now.utc + 3.hours).to_i
      set_user_login_headers(exp: exp)
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json('description' => 'Validation failed',
                 'errors' => [bad_request_error_pattern('exp', 'Expiry should be within 2 hours', code: 'invalid_value')])
    end

    def test_widget_bootstrap_with_exp_less_than_max
      exp = (Time.now.utc + 1.hour).to_i
      set_user_login_headers(exp: exp)
      get :index, construct_params(version: 'widget')
      assert_response 200
    end

    def test_widget_bootstrap_invalid_email
      User.stubs(:current).returns(nil)
      set_user_login_headers(email: 'opria')
      get :index, construct_params(version: 'widget')
      assert_response 400
      match_json([bad_request_error_pattern_with_nested_field('payload', 'email', "It should be in the 'valid email address' format", code: 'invalid_value')])
    ensure
      User.unstub(:current)
    end

    def test_widget_bootstrap_signup_failed
      User.stubs(:current).returns(nil)
      User.any_instance.stubs(:signup!).returns(false)
      set_user_login_headers
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
      set_user_login_headers(email: 'praaji.longbottom@helpdesk.com')
      get :index, construct_params(version: 'widget')
      assert_response 403
      match_json(request_error_pattern('action_restricted', action: 'login', reason: 'domain/user is restricted in Admin'))
    ensure
      @account.features.restricted_helpdesk.destroy
      @account.rollback(:restricted_helpdesk)
    end

    def test_widget_bootstrap_without_help_widget_enabled
      set_user_login_headers
      @account.revoke_feature(:help_widget)
      get :index, construct_params(version: 'widget')
      assert_response 403
      match_json('code' => 'require_feature',
                 'message' => 'The Help Widget feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
    ensure
      @account.add_feature(:help_widget)
    end
  end
end
