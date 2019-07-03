require_relative '../../../test_helper'
class Channel::Freshconnect::ContactsControllerTest < ActionController::TestCase
  include UsersTestHelper

  def setup
    super
    @account.reload
  end

  def test_contacts_show
    set_jwt_auth_header('freshconnect')
    sample_user = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1).user
    get :show, controller_params(version: 'channel', id: sample_user.id)
    ignore_keys = [:was_agent, :agent_deleted_forever, :marked_for_hard_delete]
    match_json(contact_pattern(sample_user.reload).except(*ignore_keys))
    assert_response 200
  end

  def test_contacts_show_for_non_agent
    set_jwt_auth_header('freshconnect')
    sample_user = add_new_user(@account)
    get :show, controller_params(version: 'channel', id: sample_user.id)
    assert_response 404
  end
end
