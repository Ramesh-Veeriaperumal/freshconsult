require_relative '../../../test_helper'
class Channel::Freshconnect::AgentsGroupsControllerTest < ActionController::TestCase
  include GroupsTestHelper
  include BootstrapTestHelper
  include AgentHelper

  def setup
    super
    @account.reload
  end

  def test_agents_groups_index
    @account.users.where(helpdesk_agent: true).each { |user| user.destroy if user.id != 1 }
    5.times { |i| add_agent_to_account(@account, {:name => "testing#{i}", :email => Faker::Internet.email, :active => 1, :role => 1}) }
    5.times { create_group_with_agents(@account) }
    set_jwt_auth_header('freshconnect')
    get :index, controller_params(version: 'channel')
    assert_response 200
    match_json(agent_group_pattern(Account.current))
  end
end
