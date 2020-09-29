# frozen_string_literal: true

require_relative '../../../api/test_helper'
module Notification
  class UserNotificationControllerTest < ActionController::TestCase
    JWT_ALGO = 'HS256'
    def setup
      super
      @account = Account.first
      @account.make_current
      current_account = @account
      @user = User.current
      current_user = @user
      Account.any_instance.stubs(:organisation_from_cache).returns(Organisation.new(organisation_id: Faker::Number.number(5)))
      freshid_authorization = @user.authorizations.build(provider: Freshid::Constants::FRESHID_PROVIDER, uid: SecureRandom.uuid)
      User.any_instance.stubs(:freshid_authorization).returns(freshid_authorization)
    end

    def teardown
      super
      Account.any_instance.unstub(:organisation_from_cache)
      User.any_instance.unstub(:freshid_authorization)
      Account.unstub
      User.unstub
    end

    def test_payload_pattern_with_freshid
      Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(true)
      get :token, controller_params(version: 'private')
      payload = JWT.decode JSON.parse(@response.body)['jwt'], iris_jwt_secret, JWT_ALGO
      assert_response 200
      assert_equal payload[0].key?('account_id'), true
      assert_equal payload[0].key?('user_id'), true
      assert_equal payload[0].key?('service_name'), true
      assert_equal payload[0].key?('jti'), true
      assert_equal payload[0].key?('org_id'), true
      assert_equal payload[0].key?('fresh_id'), true
    ensure
      Account.any_instance.unstub(:freshid_org_v2_enabled?)
    end

    def test_payload_pattern_without_freshid
      freshid_authorization = @user.authorizations.build(provider: Freshid::Constants::FRESHID_PROVIDER, uid: SecureRandom.uuid)
      get :token, controller_params(version: 'private')
      payload = JWT.decode JSON.parse(@response.body)['jwt'], iris_jwt_secret, JWT_ALGO
      assert_response 200
      assert_equal payload[0].key?('account_id'), true
      assert_equal payload[0].key?('user_id'), true
      assert_equal payload[0].key?('service_name'), true
      assert_equal payload[0].key?('jti'), true
      assert_equal payload[0].key?('org_id'), false
      assert_equal payload[0].key?('fresh_id'), false
    end

    private

      def iris_jwt_secret
        IrisNotificationsConfig['jwt_secret']
      end
  end
end
