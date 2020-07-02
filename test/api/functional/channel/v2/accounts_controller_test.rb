require_relative '../../../test_helper'
module Channel::V2
  class AccountsControllerTest < ActionController::TestCase

    def test_show
      get :show, controller_params(version: 'private')
      assert_response 200
      match_json(account_info(Account.current))
    end

    def test_show_when_no_user
      delete :destroy, construct_params(id: Account.current.id)

      get :show, controller_params(version: 'private')
      assert_response 403
    end

    def test_update_freshchat_domain
      @freshchat_account = Freshchat::Account.new(app_id: '09af2658-b79f-44c2-8a32-eea620df247a', enabled: 1, portal_widget_enabled: 'true', token: '417d077c-cdee-4835-8924-e591c6b9430a', domain: 'hello.freshchat.com', account_id: Account.current.id)
      Account.current.stubs(:freshchat_account).returns(@freshchat_account)
      post :update_freshchat_domain, construct_params(domain: 'test.freshchat.com')
      assert_response 200
      match_json(freshchat_account_domain_update_info('test.freshchat.com'))
    end

    def test_update_freshchat_app_id
      @freshchat_account = Freshchat::Account.new(app_id: '09af2658-b79f-44c2-8a32-eea620df247a', enabled: 1, portal_widget_enabled: 'true', token: '417d077c-cdee-4835-8924-e591c6b9430a', domain: 'hello.freshchat.com', account_id: Account.current.id)
      Account.current.stubs(:freshchat_account).returns(@freshchat_account)
      post :update_freshchat_domain, construct_params(app_id: 'dummy')
      assert_response 400
      match_json(freshchat_account_domain_update_failure_info)
    end

    private

    def account_info(account)
      response = {
          account: {
              id: account.id,
              plan: account.subscription.subscription_plan.display_name,
              pod: PodConfig['CURRENT_POD']
          }
      }
      response
    end

    def freshchat_account_domain_update_info(freshchat_account_domain)
      response = {
        message: "Freshchat domain updated successfully - #{freshchat_account_domain}"
      }
      response
    end

    def freshchat_account_domain_update_failure_info
      response = {
        "description": "Validation failed",
        "errors": [
          {
            "field": "app_id",
            "message": "Unexpected/invalid field in request",
            "code": "invalid_field"
          }
        ]
      }
      response
    end
  end
end