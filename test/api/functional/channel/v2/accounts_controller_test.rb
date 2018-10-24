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
  end
end