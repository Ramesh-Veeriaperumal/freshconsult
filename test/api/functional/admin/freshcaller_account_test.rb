require_relative '../../../test_helper'
include Freshcaller::TestHelper

module Admin
  class FreshcallerAccountControllerTest < ActionController::TestCase

    def test_show_with_no_feature_check
      Account.current.rollback :freshcaller_admin_new_ui
      get :show, controller_params(version: 'private')
      assert_response Rack::Utils::SYMBOL_TO_STATUS_CODE[:forbidden]
      match_json({code: 'require_feature', message: 
            'The Freshcaller,Freshcaller Admin New Ui feature(s) is/are not supported in your plan. Please upgrade your account to use it.'})
    end

    def test_show_with_freshcaller_account_associated_and_enabled_state
      Account.current.launch :freshcaller_admin_new_ui
      Account.current.add_feature :freshcaller
      create_freshcaller_account unless Account.current.freshcaller_account
      freshcaller_account = Account.current.freshcaller_account
      get :show, controller_params(version: 'private')
      assert_response 200
      match_json(freshcaller_account.as_api_response(:api))
    ensure
      Account.current.rollback :freshcaller_admin_new_ui
      Account.current.revoke_feature :freshcaller
    end

    def test_show_with_freshcaller_account_disabled_state
      Account.current.launch :freshcaller_admin_new_ui
      Account.current.add_feature :freshcaller
      create_freshcaller_account unless Account.current.freshcaller_account
      freshcaller_account = Account.current.freshcaller_account
      freshcaller_account.enabled = false
      freshcaller_account.save!
      freshcaller_account.reload
      get :show, controller_params(version: 'private')
      assert_response 200
      match_json(freshcaller_account.as_api_response(:api))
    ensure
      Account.current.rollback :freshcaller_admin_new_ui
      Account.current.revoke_feature :freshcaller
    end

    def test_show_with_feature_and_no_freshcaller_account_associated
      Account.current.launch :freshcaller_admin_new_ui
      Account.current.add_feature :freshcaller
      delete_freshcaller_account if Account.current.freshcaller_account
      get :show, controller_params(version: 'private')
      assert_response 204
    ensure
      Account.current.rollback :freshcaller_admin_new_ui
      Account.current.revoke_feature :freshcaller
    end
  end
end