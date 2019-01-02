require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('spec', 'support', 'automations_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')

class BulkScenarioTest < ActionView::TestCase
  include ApiTicketsTestHelper
  include UsersHelper
  include ControllerTestHelper
  include AutomationsHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @agent = get_admin
    @agent.make_current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def rule_param(access_type = :all, group_ids = nil, user_ids = nil)
    {
      account_id: @account.id,
      accessible_attributes:
        {
          access_type: Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[access_type],
          group_ids: group_ids,
          user_ids: user_ids
        }
    }
  end

  def test_bulk_scenario_with_all
    test_scn = create_scn_automation_rule(rule_param)
    ticket_ids = create_n_tickets(3, priority: 2)
    Tickets::BulkScenario.new.perform(ticket_ids: ticket_ids, scenario_id: test_scn.id)
    @account.tickets.where(display_id: ticket_ids).each do |ticket|
      assert ticket.priority == 3
    end
  end

  def test_bulk_scenario_with_invalid_user
    user = add_new_user(@account)
    User.stubs(:current).returns(user)
    test_scn = create_scn_automation_rule(rule_param(:users, nil, [@agent.id]))
    ticket_ids = create_n_tickets(3, priority: 2)
    Tickets::BulkScenario.new.perform(ticket_ids: ticket_ids, scenario_id: test_scn.id)
    @account.tickets.where(display_id: ticket_ids).each do |ticket|
      assert ticket.priority == 2
    end
    User.unstub(:current)
  end

  def test_bulk_scenario_with_user
    test_scn = create_scn_automation_rule(rule_param(:users, nil, [@agent.id]))
    ticket_ids = create_n_tickets(3, priority: 2)
    Tickets::BulkScenario.new.perform(ticket_ids: ticket_ids, scenario_id: test_scn.id)
    @account.tickets.where(display_id: ticket_ids).each do |ticket|
      assert ticket.priority == 3
    end
  end

  def test_bulk_scenario_with_invalid_group
    user = add_new_user(@account)
    User.stubs(:current).returns(user)
    test_scn = create_scn_automation_rule(rule_param(:groups, [1]))
    ticket_ids = create_n_tickets(3, priority: 2)
    Tickets::BulkScenario.new.perform(ticket_ids: ticket_ids, scenario_id: test_scn.id)
    @account.tickets.where(display_id: ticket_ids).each do |ticket|
      assert ticket.priority == 2
    end
    User.unstub(:current)
  end

  def test_bulk_scenario_with_group
    test_scn = create_scn_automation_rule(rule_param(:groups, [1]))
    ticket_ids = create_n_tickets(3, priority: 2)
    Tickets::BulkScenario.new.perform(ticket_ids: ticket_ids, scenario_id: test_scn.id)
    @account.tickets.where(display_id: ticket_ids).each do |ticket|
      assert ticket.priority == 3
    end
  end

  def test_bulk_scenario_with_exception
    assert_nothing_raised do
      Tickets::BulkScenario.new.perform(nil)
    end
  end

  def test_bulk_scenario_with_exception_in_ticket
    assert_nothing_raised do
      test_scenario = create_scn_automation_rule(rule_param)
      ticket_ids = create_n_tickets(3, priority: 2)
      Helpdesk::Ticket.any_instance.stubs(:save).raises(RuntimeError)
      Tickets::BulkScenario.new.perform(ticket_ids: ticket_ids, scenario_id: test_scenario.id)
      Helpdesk::Ticket.any_instance.unstub(:save)
      @account.tickets.where(display_id: ticket_ids).each do |ticket|
        assert ticket.priority == 2
      end
    end
  end
end
