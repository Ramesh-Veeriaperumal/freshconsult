require_relative '../../test_helper'
class Ember::BootstrapControllerTest < ActionController::TestCase
  include BootstrapTestHelper
  include AgentsTestHelper
  include AttachmentsTestHelper

  def test_index
    get :index, controller_params(version: 'private')
    assert_response 200
    match_json(index_pattern(@agent.agent, Account.current, Account.current.portals.first))
  end

  def test_me
    get :me, controller_params(version: 'private')
    assert_response 200
    match_json(agent_info_pattern(@agent.agent))
  end

  def test_account
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
  end

  def test_account_with_fav_icon_for_portal
    portal = Account.current.main_portal
    file = fixture_file_upload('/files/image33kb.jpg', 'image/jpg')
    fav_icon = create_attachment(content: file, attachable_type: 'Portal', attachable_id: portal.id, description: 'fav_icon')
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, portal))
  end

  def test_collision_autorefresh_freshid_keys
    Account.current.features.collision.create
    Account.current.add_feature(:auto_refresh)
    Account.current.launch(:freshid)
    Account.current.reload
    get :index, controller_params(version: 'private')
    agent_info = ActiveSupport::JSON.decode(response.body)['agent']
    assert_not_nil response.api_meta[:collision_url]
    assert_not_nil response.api_meta[:autorefresh_url]
    assert_not_nil response.api_meta[:freshid_url]
    assert_not_nil response.api_meta[:freshid_profile_url]
    assert_not_nil agent_info['autorefresh_user_hash']
    assert_not_nil agent_info['collision_user_hash']

    Account.current.features.collision.destroy
    Account.current.rollback(:freshid)
    Account.current.revoke_feature(:auto_refresh)
    Account.current.reload
    get :index, controller_params(version: 'private')
    agent_info = ActiveSupport::JSON.decode(response.body)['agent']
    assert_nil response.api_meta[:collision_url]
    assert_nil response.api_meta[:autorefresh_url]
    assert_nil response.api_meta[:freshid_url]
    assert_nil response.api_meta[:freshid_profile_url]
    assert_nil agent_info['autorefresh_user_hash']
    assert_nil agent_info['collision_user_hash']
  end

  def test_launchparty
    Account.current.add_feature(:falcon)
    Account.current.reload
    get :index, controller_params(version: 'private')
    assert_response 200

    Account.current.revoke_feature(:falcon)
    Account.current.rollback(:falcon)
    Account.current.reload

    get :index, controller_params(version: 'private')
    assert_response 404

    Account.current.add_feature(:falcon)

    Account.current.reload
  end

  def test_custom_dashboard_limits_without_feature
    Account.current.stubs(:custom_dashboard_enabled?).returns(false)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
  end

  def test_custom_dashboard_limits_with_feature
    Account.current.stubs(:custom_dashboard_enabled?).returns(true)
    get :account, controller_params(version: 'private')
    assert_response 200
    match_json(account_pattern(Account.current, Account.current.main_portal))
  end

end
