require_relative '../../test_transactions_fixtures_helper'
require_relative '../test_helper'
require_relative '../../core/helpers/users_test_helper'
require 'sidekiq/testing'
require 'minitest'
Sidekiq::Testing.fake!

class UpdateUserPrivilegesTest < ActionView::TestCase
  include CoreUsersTestHelper
  include RolesTestHelper

  def setup
    create_test_account if Account.first.nil?
    Account.stubs(:current).returns(Account.first)
    @account = Account.first
    User.stubs(:current).returns(@account.all_technicians.first)
    # To Prevent agent central publish error
    Agent.any_instance.stubs(:user_uuid).returns('123456789')
  end

  def teardown
    Account.unstub(:current)
    User.unstub(:current)
    super
  end

  def test_user_privilege_update_on_role_update
    user_ids = []
    privileges = ['manage_tickets', 'edit_ticket_properties', 'view_forums',
                  'view_contacts', 'manage_contacts', 'view_reports', '', '0',
                  '0', '0', '0']
    test_role = create_role(name: 'Test Role 3', privilege_list: privileges)
    2.times do
      user = add_agent(@account)
      user_ids.push(user.id.to_s)
    end
    # To test adding of roles to agents via job
    args = { add_user_ids: user_ids, delete_user_ids: nil, role_id: test_role.id }
    Roles::UpdateAgentsRoles.new.perform(args)

    test_role.update_attributes({ privilege_list: ['create_topic'] })
    test_role.reload

    args = { role_id: test_role.id, performed_by_id: User.current.id }
    Roles::UpdateUserPrivileges.new.perform(args)
    user_ids.each do |user_id|
      user = @account.users.find_by_id(user_id)
      assert_equal true, user.privilege?(:create_topic)
    end
  ensure
    user_ids.each do |user_id|
      @account.users.find(user_id).destroy
    end
    @account.roles.find(test_role.id).destroy
  end
end

