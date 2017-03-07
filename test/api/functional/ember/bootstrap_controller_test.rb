require_relative '../../test_helper'
class Ember::BootstrapControllerTest < ActionController::TestCase
  include BootstrapTestHelper

  def test_index
    get :index, controller_params(version: 'private')
    assert_response 200
    match_json(index_pattern(@agent.agent, Account.current))
  end

  def test_launchparty

    Account.current.launch(:falcon)
    Account.current.reload
    get :index, controller_params(version: 'private')
    assert_response 200

    Account.current.rollback(:falcon)
    Account.current.reload

    get :index, controller_params(version: 'private')
    assert_response 404

    Account.current.launch(:falcon)
    Account.current.reload
  end
end
