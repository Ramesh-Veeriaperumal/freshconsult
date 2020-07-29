require_relative '../../test_transactions_fixtures_helper'
require_relative '../test_helper'
require_relative '../../core/helpers/users_test_helper'
require 'sidekiq/testing'
require 'minitest'
Sidekiq::Testing.fake!

class UpdateAgentsRolesTest < ActionView::TestCase
  include CoreUsersTestHelper
  include RolesTestHelper

  def setup
    create_test_account if Account.first.nil?
    Account.stubs(:current).returns(Account.first)
    @account = Account.first
    # To Prevent agent central publish error
    Agent.any_instance.stubs(:user_uuid).returns('123456789')
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_add_delete_roles_with_agents
    user_ids = []
    privileges = ['manage_tickets', 'edit_ticket_properties', 'view_forums',
                  'view_contacts', 'manage_contacts', 'view_reports', '', '0',
                  '0', '0', '0']
    test_role = create_role(name: 'Test Role1', privilege_list: privileges)
    5.times do
      user = add_agent(@account)
      user_ids.push(user.id.to_s)
    end
    # To test adding of roles to agents via job
    args = { add_user_ids: user_ids, delete_user_ids: nil, role_id: test_role.id }
    Roles::UpdateAgentsRoles.new.perform(args)
    assert_equal 5, @account.users.joins(:user_roles).where(user_roles: {role_id: test_role.id}).count

    # To test deleting of roles to agents via job
    args = { add_user_ids: nil, delete_user_ids: user_ids, role_id: test_role.id }
    Roles::UpdateAgentsRoles.new.perform(args)
    assert_equal 0, @account.users.joins(:user_roles).where(user_roles: {role_id: test_role.id}).count
  ensure
    user_ids.each do |user_id|
      @account.users.find(user_id).destroy
    end
    @account.roles.find(test_role.id).destroy
  end

  def test_passing_invalid_agent
    privileges = ['manage_tickets', 'edit_ticket_properties', 'view_forums',
                  'view_contacts', 'manage_contacts', 'view_reports', '', '0',
                  '0', '0', '0']
    test_role = create_role(name: 'Test Role2', privilege_list: privileges)
    args = { add_user_ids: ["10000000", "20000000"], delete_user_ids: nil, role_id: test_role.id }
    Roles::UpdateAgentsRoles.new.perform(args)
    assert_equal 0, @account.users.joins(:user_roles).where(user_roles: {role_id: test_role.id}).count

    user = add_agent(@account)
    args = { add_user_ids: [user.id.to_s], delete_user_ids: ["100000000", "30000000"], role_id: test_role.id }
    Roles::UpdateAgentsRoles.new.perform(args)
    assert_equal 1, @account.users.joins(:user_roles).where(user_roles: {role_id: test_role.id}).count

  ensure
    @account.users.find(user.id).destroy if user.present? && @account.users.find(user.id).present?
    @account.roles.find(test_role.id).destroy if test_role.present? && @account.roles.find(test_role.id).present?
  end
end
