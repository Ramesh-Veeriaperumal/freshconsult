require_relative '../../test_helper'
class Ember::BootstrapControllerTest < ActionController::TestCase
  include BootstrapTestHelper

  def test_index
    get :index, controller_params(version: 'private')
    assert_response 200
    match_json(index_pattern(@agent.agent, Account.current))
  end
end
