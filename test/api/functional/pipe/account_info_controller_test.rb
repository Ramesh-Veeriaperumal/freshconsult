require_relative '../../test_helper'

module Pipe
  class AccountInfoControllerTest < ActionController::TestCase

    def test_info_correct_account_id
      get :index, controller_params(version: 'pipe', account_id: @account.id)
      assert_response 200
      match_json(account_info(@account))
    end

    def test_info_non_existent_account
      assert_raises ActiveRecord::RecordNotFound do
        get :index, controller_params(version: 'pipe', account_id: 23423425235)
      end
    end

    private

    def account_info(account)
      {
        status: account.subscription.state,
        plan: account.plan_name,
        features: (account.feature_from_cache + account.features_list).uniq
      }
    end
  end
end