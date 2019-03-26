require_relative '../../../api/unit_test_helper'

class RoundRobinMethodsTest < ActionView::TestCase
  def setup
    Account.stubs(:current).returns(Account.first)
    @ticket = Account.first.tickets.new
    Group.any_instance.stubs(:lrem_from_rr_capping_queue).returns(nil)
    Helpdesk::Ticket.any_instance.stubs(:save).returns(true)
  end

  def teardown
    Account.unstub(:current)
    Group.any_instance.unstub(:lrem_from_rr_capping_queue)
    Helpdesk::Ticket.any_instance.unstub(:save)
    super
  end

  def test_assign_tickets_to_agents_no_available_agent
    Helpdesk::Ticket.any_instance.stubs(:group).returns(Group.new)
    Group.any_instance.stubs(:ticket_assign_type).returns(1)
    Account.any_instance.stubs(:features?).returns(true)
    agent = @ticket.assign_tickets_to_agents
    assert_equal true, agent
  end

  def test_agent_tickets_to_agents_with_responder
    Helpdesk::Ticket.any_instance.stubs(:group).returns(Group.new)
    Helpdesk::Ticket.any_instance.stubs(:has_capping_status?).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:zscore_round_robin_redis).returns(1, nil)
    Helpdesk::Ticket.any_instance.stubs(:watch_round_robin_redis).returns(nil)
    Group.any_instance.stubs(:ticket_assign_type).returns(1)
    Group.any_instance.stubs(:update_agent_capping_with_lock).returns([0, 1])
    Group.any_instance.stubs(:capping_enabled?).returns(true)
    Group.any_instance.stubs(:lrem_from_rr_capping_queue).returns(true)
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:round_robin_capping_enabled?).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(Account.first.contacts.last.id)
    agent = @ticket.assign_tickets_to_agents
    assert_equal nil, agent
  end

  def test_round_robin_on_ticket_update_no_update
    Helpdesk::Ticket.any_instance.stubs(:group).returns(Group.new)
    Group.any_instance.stubs(:capping_enabled?).returns(true)
    Account.any_instance.stubs(:round_robin_capping_enabled?).returns(true)
    upd = @ticket.round_robin_on_ticket_update({})
    assert_equal [], upd
  end

  def test_round_robin_on_ticket_update_no_round_capping
    Helpdesk::Ticket.any_instance.stubs(:group).returns(Group.new)
    Group.any_instance.stubs(:round_robin_capping_enabled?).returns(false)
    upd = @ticket.round_robin_on_ticket_update(group_id: 1)
    assert_equal nil, upd
  end

  def test_assign_agent_via_round_robin
    Helpdesk::Ticket.any_instance.stubs(:group).returns(Group.new)
    Helpdesk::Ticket.any_instance.stubs(:group_id).returns(1)
    Helpdesk::Ticket.any_instance.stubs(:status).returns(Helpdesk::TicketStatus::sla_timer_on_status_ids(Account.first).first)
    Account.any_instance.stubs(:round_robin_capping_enabled?).returns(true)
    Group.any_instance.stubs(:capping_enabled?).returns(true)
    Group.any_instance.stubs(:next_agent_with_capping).returns(Agent.new)
    assign = @ticket.assign_agent_via_round_robin
    assert_equal 'round_robin', assign[:type]
  end

  def test_incr_agent_capping_limit
    Helpdesk::Ticket.any_instance.stubs(:account).returns(Account.first)
    Account.any_instance.stubs(:groups).returns(Group.new)
    Group.any_instance.stubs(:find_by_id).returns(Group.new)
    incr = @ticket.incr_agent_capping_limit(1, 1)
    assert_equal nil, incr
  end

  def test_incr_agent_capping_limit_no_agent_id
    Helpdesk::Ticket.any_instance.stubs(:account).returns(Account.first)
    Helpdesk::Ticket.any_instance.stubs(:group).returns(nil)
    Account.any_instance.stubs(:groups).returns(Group.new)
    Group.any_instance.stubs(:find_by_id).returns(Group.new)
    incr = @ticket.incr_agent_capping_limit(nil, 1)
    assert_equal nil, incr
  end

  def test_decr_agent_capping_limit
    Helpdesk::Ticket.any_instance.stubs(:account).returns(Account.first)
    Account.any_instance.stubs(:groups).returns(Group.new)
    Group.any_instance.stubs(:find_by_id).returns(Group.new)
    decr = @ticket.decr_agent_capping_limit(1, 1)
    assert_equal true, decr
  end

  def test_decr_agent_capping_limit_no_agent_id
    Helpdesk::Ticket.any_instance.stubs(:account).returns(Account.first)
    Account.any_instance.stubs(:groups).returns(Group.new)
    Group.any_instance.stubs(:find_by_id).returns(nil)
    decr = @ticket.decr_agent_capping_limit(nil, 1)
    assert_equal nil, decr
  end

  def test_rr_allowed_on_update
    Helpdesk::Ticket.any_instance.stubs(:group).returns(nil)
    rr_allowed = @ticket.rr_allowed_on_update?
    assert_equal nil, rr_allowed
  end

  def test_has_valid_status
    Helpdesk::Ticket.any_instance.stubs(:has_capping_status?).returns(nil)
    status = @ticket.has_valid_status?({})
    assert_equal nil, status
  end

  def test_set_sbrr_skill_activity
    Helpdesk::Ticket.any_instance.stubs(:sl_skill_id).returns(nil)
    Helpdesk::Ticket.any_instance.stubs(:model_changes).returns(sl_skill_id: 1)
    activity = @ticket.set_sbrr_skill_activity
    assert_equal nil, activity
  end

  def test_change_agents_ticket_count_all_nil
    count = @ticket.change_agents_ticket_count(nil, nil, nil)
    assert_equal nil, count
  end

  def test_update_old_group_capping_nil_responder
    Helpdesk::Ticket.any_instance.stubs(:group).returns(Group.new)
    Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(nil)
    Helpdesk::Ticket.any_instance.stubs(:has_valid_status?).returns(true)
    Group.any_instance.stubs(:try).returns(false)
    Account.any_instance.stubs(:groups).returns(Group.new)
    Group.any_instance.stubs(:find_by_id).returns(Group.new)
    Group.any_instance.stubs(:lbrr_enabled?).returns(Group.new)
    capping = @ticket.update_old_group_capping(group_id: 1)
    assert_equal nil, capping
  end

  def test_update_old_group_capping_with_responder
    Helpdesk::Ticket.any_instance.stubs(:group).returns(Group.new)
    Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(1)
    Helpdesk::Ticket.any_instance.stubs(:has_valid_status?).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:change_agents_ticket_count).returns(nil)
    Group.any_instance.stubs(:try).returns(false)
    Account.any_instance.stubs(:groups).returns(Group.new)
    Group.any_instance.stubs(:find_by_id).returns(Group.new)
    Group.any_instance.stubs(:lbrr_enabled?).returns(Group.new)
    capping = @ticket.update_old_group_capping(group_id: 1)
    assert_equal nil, capping
  end

  def test_check_capping_conditions_with_spam_false
    Helpdesk::Ticket.any_instance.stubs(:has_valid_status?).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:incr_agent_capping_limit).returns(nil)
    Helpdesk::Ticket.any_instance.stubs(:fetch_lbrr_id).returns(1)
    Helpdesk::Ticket.any_instance.stubs(:deleted).returns(false)
    conditions = @ticket.check_capping_conditions(spam: false)
    assert_equal true, conditions.present?
  end

  def test_check_capping_conditions_with_status
    Helpdesk::Ticket.any_instance.stubs(:lbrr_status_change?).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:incr_agent_capping_limit).returns(nil)
    Helpdesk::Ticket.any_instance.stubs(:fetch_lbrr_id).returns(1)
    conditions = @ticket.check_capping_conditions(status:{ test: true })
    assert_equal true, conditions.present?
  end

  def test_check_capping_conditions_with_status_false
    Helpdesk::Ticket.any_instance.stubs(:lbrr_status_change?).returns(false, true)
    Helpdesk::Ticket.any_instance.stubs(:decr_agent_capping_limit).returns(nil)
    Helpdesk::Ticket.any_instance.stubs(:fetch_lbrr_id).returns(1)
    conditions = @ticket.check_capping_conditions(status:{ test: true })
    assert_equal true, conditions.present?
  end

  def test_check_capping_conditions_with_responder_id
    Helpdesk::Ticket.any_instance.stubs(:has_capping_status?).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:fetch_lbrr_id).returns(nil)
    Helpdesk::Ticket.any_instance.stubs(:account).returns(Account.first)
    conditions = @ticket.check_capping_conditions(responder_id: 1)
    assert_equal [], conditions
  end
end
