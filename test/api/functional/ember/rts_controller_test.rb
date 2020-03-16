require_relative '../../test_helper'
module Ember
  class RtsControllerTest < ActionController::TestCase
    def setup
      super
      @account = Account.first
      @account.make_current
      Account.any_instance.stubs(:agent_collision_revamp_enabled?).returns(true)
      @stub_time = Time.now.utc
      Time.stubs(:now).returns(@stub_time)
      acc_add_settings = @account.account_additional_settings
      acc_add_settings.additional_settings[:rts_account_id] = rts_details[:rts_account_id]
      acc_add_settings.assign_rts_account_secret(rts_details[:rts_secret])
      acc_add_settings.save
    end

    def teardown
      super
      Account.unstub
    end

    def test_fetch_rts_account_details_success
      get :show, controller_params(version: 'private')
      match_json(rts_response_pattern)
      assert_response 200
    end

    def test_fetch_details_rts_account_not_created
      acc_add_settings = @account.account_additional_settings
      acc_add_settings.additional_settings.delete(:rts_account_id)
      acc_add_settings.secret_keys.delete(:rts_account_secret)
      acc_add_settings.save
      get :show, controller_params(version: 'private')
      match_json(rts_account_id: nil, url: rts_details[:url], token: nil)
      assert_response 200
    end

    def test_fetch_details_rts_access_denied
      Account.any_instance.stubs(:agent_collision_revamp_enabled?).returns(false)
      get :show, controller_params(version: 'private')
      assert_response 403
    end

    private

      def rts_details
        @rts_details || {
          rts_account_id: 'EO2GQMVGO9',
          rts_secret: 'sBDW9l0iQNBAWpJqbUDMtoSejplfsJ3PYSIS9tgDP-Q=',
          current_user_id: '1',
          url: 'https://rts-staging.freshworksapi.com'
        }
      end

      def rts_response_pattern
        {
          rts_account_id: rts_details[:rts_account_id],
          url: rts_details[:url],
          token: generate_jwt
        }
      end

      def generate_jwt
        JWT.encode(payload, rts_details[:rts_secret], RTS::Constants::RTS_JWT_ALGO)
      end

      def payload
        {
          accId: rts_details[:rts_account_id],
          userId: rts_details[:current_user_id],
          exp: @stub_time.to_i + 10.hours,
          credentials: [{
            resource: '*',
            perms: ['*'],
            expire: @stub_time.to_i + 10.hours
          }]
        }
      end
  end
end
