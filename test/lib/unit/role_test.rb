# frozen_string_literal: true

require_relative '../../api/unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'roles_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'test_case_methods')

class RoleTest < ActiveSupport::TestCase
  include AccountTestHelper
  include RolesTestHelper
  include TestCaseMethods

  def setup
    create_test_account if Account.first.nil?
    Account.stubs(:current).returns(Account.first)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_conditional_privileges_set_on_adding_privileges
    role = create_role(name: Faker::Name.name, privilege_list: ['', '0'])
    success_privileges = [:create_ticket, :execute_scenario_automation, :manage_parent_child_tickets, :manage_linked_tickets,
                          :create_service_tasks, :delete_service_tasks, :ticket_assignee, :ticket_internal_assignee]
    role.agent_type = 1
    role.privilege_list = ['manage_tickets', 'edit_ticket_properties', 'view_forums', 'view_contacts', 'delete_ticket',
                           'view_reports', '', '0', '0', '0', '0']
    role.save!
    new_privilege_list = role.reload.privilege_list
    assert_equal true, (success_privileges - new_privilege_list).empty?
  end

  def test_conditional_privileges_not_set_on_failed_condition
    role = create_role(name: Faker::Name.name, privilege_list: ['', '0'])
    success_privileges = [:create_ticket, :execute_scenario_automation, :manage_parent_child_tickets, :manage_linked_tickets,
                          :create_service_tasks, :delete_service_tasks, :ticket_assignee, :ticket_internal_assignee]
    role.agent_type = 3
    role.privilege_list = ['manage_tickets', 'edit_ticket_properties', 'view_forums', 'view_contacts', 'delete_ticket',
                           'view_reports', '', '0', '0', '0', '0']
    role.save!
    new_privilege_list = role.reload.privilege_list
    assert_equal true, (success_privileges.none? { |i| new_privilege_list.include?(i) })
    assert_equal false, (success_privileges - new_privilege_list).empty?
  end

  def test_conditional_privileges_random_case_one
    random_case_one = { manage_tickets: [{ privilege: [:create_ticket], condition_key: :agent_type, condition_values: [3] }] }
    stub_const(Helpdesk::PrivilegesMap, :CONDITION_BASED_PRIVILEGES, random_case_one) do
      role = create_role(name: Faker::Name.name, privilege_list: ['', '0'])
      role.agent_type = 1
      role.privilege_list = ['manage_tickets', 'edit_ticket_properties', 'view_forums', 'view_contacts', 'delete_ticket',
                             'view_reports', '', '0', '0', '0', '0']
      role.save!
      new_privilege_list = role.reload.privilege_list
      assert_equal false, new_privilege_list.include?(:create_ticket)

      role.agent_type = 3
      role.privilege_list = ['manage_tickets', 'edit_ticket_properties', 'view_forums', 'view_contacts', 'delete_ticket',
                             'view_reports', '', '0', '0', '0', '0']
      role.save!
      new_privilege_list = role.reload.privilege_list
      assert_equal true, new_privilege_list.include?(:create_ticket)
    end
  end

  def test_conditional_privileges_random_case_two
    random_case_two = { create_service_tasks: [{ privilege: [:manage_service_task_automation_rules], condition_key: :agent_type, condition_values: [2] }] }
    stub_const(Helpdesk::PrivilegesMap, :CONDITION_BASED_PRIVILEGES, random_case_two) do
      role = create_role(name: Faker::Name.name, privilege_list: ['', '0'])
      role.agent_type = 1
      role.privilege_list = ['manage_tickets', 'edit_ticket_properties', 'view_forums', 'view_contacts', 'delete_ticket',
                             'view_reports', '', '0', '0', '0', '0']
      role.save!
      new_privilege_list = role.reload.privilege_list
      assert_equal false, new_privilege_list.include?(:manage_service_task_automation_rules)

      role.agent_type = 3
      role.privilege_list = ['manage_tickets', 'edit_ticket_properties', 'view_forums', 'view_contacts', 'delete_ticket',
                             'view_reports', '', '0', '0', '0', '0']
      role.save!
      new_privilege_list = role.reload.privilege_list
      assert_equal false, new_privilege_list.include?(:manage_service_task_automation_rules)

      role.agent_type = 3
      role.privilege_list = ['manage_tickets', 'create_service_tasks', 'edit_ticket_properties', 'view_forums', 'view_contacts', 'delete_ticket',
                             'view_reports', '', '0', '0', '0', '0']
      role.save!
      new_privilege_list = role.reload.privilege_list
      assert_equal false, new_privilege_list.include?(:manage_service_task_automation_rules)

      role.agent_type = 2
      role.privilege_list = ['manage_tickets', 'create_service_tasks', 'edit_ticket_properties', 'view_forums', 'view_contacts', 'delete_ticket',
                             'view_reports', '', '0', '0', '0', '0']
      role.save!
      new_privilege_list = role.reload.privilege_list
      assert_equal true, new_privilege_list.include?(:manage_service_task_automation_rules)

      role.agent_type = 2
      role.privilege_list = ['manage_tickets', 'edit_ticket_properties', 'view_forums', 'view_contacts', 'delete_ticket',
                             'view_reports', '', '0', '0', '0', '0']
      role.save!
      new_privilege_list = role.reload.privilege_list
      assert_equal false, new_privilege_list.include?(:manage_service_task_automation_rules)
    end
  end
end
