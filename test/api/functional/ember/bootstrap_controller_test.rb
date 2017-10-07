require_relative '../../test_helper'
class Ember::BootstrapControllerTest < ActionController::TestCase
  include BootstrapTestHelper
  include AgentsTestHelper

  def test_index
    get :index, controller_params(version: 'private')
    assert_response 200
    match_json(index_pattern(@agent.agent, Account.current, Account.current.portals.first))
  end

  def test_collision_autorefresh_keys
    Account.current.features.collision.create
    Account.current.add_feature(:auto_refresh)
    Account.current.reload
    get :index, controller_params(version: 'private')
    agent_info = ActiveSupport::JSON.decode(response.body)['agent']
    assert_not_nil response.api_meta[:collision_url]
    assert_not_nil response.api_meta[:autorefresh_url]
    assert_not_nil agent_info['autorefresh_user_hash']
    assert_not_nil agent_info['collision_user_hash']

    Account.current.features.collision.destroy
    Account.current.revoke_feature(:auto_refresh)
    Account.current.reload
    get :index, controller_params(version: 'private')
    agent_info = ActiveSupport::JSON.decode(response.body)['agent']
    assert_nil response.api_meta[:collision_url]
    assert_nil response.api_meta[:autorefresh_url]
    assert_nil agent_info['autorefresh_user_hash']
    assert_nil agent_info['collision_user_hash']
  end

  def test_launchparty
    Account.current.add_feature(:falcon)
    Account.current.reload
    get :index, controller_params(version: 'private')
    assert_response 200

    Account.current.revoke_feature(:falcon)
    Account.current.reload

    get :index, controller_params(version: 'private')
    assert_response 404

    Account.current.add_feature(:falcon)
    Account.current.reload
  end
end
