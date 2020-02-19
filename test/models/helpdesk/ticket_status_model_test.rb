require_relative '../test_helper'
['account_helper.rb', 'user_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

class TicketStatusModelTest < ActiveSupport::TestCase
  include AccountHelper
  include UsersHelper
  include TicketsTestHelper
  include TicketStatusTestHelper
  include ModelsGroupsTestHelper
  include MemcacheKeys

  def setup
    super
    key = format(ACCOUNT_STATUSES, account_id: Account.current.id)
    MemcacheKeys.delete_from_cache key
    Account.current.instance_variable_set('@ticket_status_values_from_cache', nil)
  end

  def test_status_names_should_return_all_statuses_name_ids
    ticket_status = create_ticket_status
    status_names = Account.current.ticket_statuses.status_names(Account.current)
    assert_equal status_names.class, Array
    assert status_names.include?([ticket_status.status_id, ticket_status.name])
  ensure
    ticket_status.destroy
  end

  def test_donot_stop_sla_statuses_should_return_all_status_ids_where_stop_sla_timer_is_false
    ticket_status = create_ticket_status(stop_sla_timer: 0)
    status_ids = Account.current.ticket_statuses.donot_stop_sla_statuses(Account.current)
    assert_equal status_ids.class, Array
    assert status_ids.include?(ticket_status.status_id)
  ensure
    ticket_status.destroy
  end

  def test_onhold_and_closed_statuses_should_return_all_status_ids_where_stop_sla_timer_is_true
    ticket_status = create_ticket_status(stop_sla_timer: 1)
    status_ids = Account.current.ticket_statuses.onhold_and_closed_statuses(Account.current)
    assert_equal status_ids.class, Array
    assert status_ids.include?(ticket_status.status_id)
  ensure
    ticket_status.destroy
  end

  def test_open_should_return_false_if_not_open_status
    ticket_status = create_ticket_status
    assert_equal ticket_status.open?, false
  ensure
    ticket_status.destroy
  end

  def test_open_should_return_true_if_open_status
    assert_equal Account.current.ticket_statuses.find_by_status_id(2).open?, true
  end

  def test_pending_should_return_false_if_not_pending_status
    ticket_status = create_ticket_status
    assert_equal ticket_status.pending?, false
  ensure
    ticket_status.destroy
  end

  def test_pending_should_return_true_if_pending_status
    assert_equal Account.current.ticket_statuses.find_by_status_id(3).pending?, true
  end

  def test_group_ids_with_names_returns_status_group_info
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    key = format(ACCOUNT_STATUS_GROUPS, account_id: Account.current.id)
    MemcacheKeys.delete_from_cache key
    ticket_status = create_ticket_status
    group = create_group(Account.current)
    ticket_status.group_ids = [group.id]
    ticket_status.save!
    Account.current.instance_variable_set('@account_status_groups_from_cache', nil)
    status_group_info = Account.current.ticket_statuses.group_ids_with_names([ticket_status])
    assert_equal status_group_info, ticket_status.status_id => [group.id]
  ensure
    ticket_status.destroy
    group.destroy
    Account.any_instance.unstub(:shared_ownership_enabled?)
  end

  def test_onhold_returns_true_if_status_is_onhold
    ticket_status_pending = Account.current.ticket_statuses.where(name: 'Pending').first
    ticket_status_waiting_on_customer = Account.current.ticket_statuses.where(name: 'Waiting on Customer').first
    assert_equal ticket_status_pending.onhold?, true
    assert_equal ticket_status_waiting_on_customer.onhold?, true
  end

  def test_onhold_returns_false_if_status_is_not_onhold
    ticket_status = Account.current.ticket_statuses.where(name: 'Open').first
    assert_equal ticket_status.onhold?, false
  end

  def test_onhold_and_closed_returns_true_if_status_is_onhold_or_closed
    ticket_status_pending = Account.current.ticket_statuses.where(name: 'Pending').first
    ticket_status_resolved = Account.current.ticket_statuses.where(name: 'Resolved').first
    ticket_status_waiting_on_customer = Account.current.ticket_statuses.where(name: 'Waiting on Customer').first
    ticket_status_closed = Account.current.ticket_statuses.where(name: 'Closed').first
    assert_equal ticket_status_pending.onhold_and_closed?, true
    assert_equal ticket_status_resolved.onhold_and_closed?, true
    assert_equal ticket_status_waiting_on_customer.onhold_and_closed?, true
    assert_equal ticket_status_closed.onhold_and_closed?, true
  end

  def test_onhold_and_closed_returns_false_if_status_is_not_onhold_or_closed
    ticket_status = Account.current.ticket_statuses.where(name: 'Open').first
    assert_equal ticket_status.onhold_and_closed?, false
  end

  def test_statuses_should_return_all_statuses
    ticket_status = create_ticket_status
    statuses = Account.current.ticket_statuses.statuses(Account.current)
    assert statuses.include?([ticket_status.name, ticket_status.status_id])
  ensure
    ticket_status.destroy
  end

  def test_status_should_be_deleted_on_all_jobs_completion_tf_revamp_enabled
    ticket_status = create_ticket_status
    ticket_status.deleted = true
    ticket_status.save!
    Account.current.launch :ticket_field_revamp
    Sidekiq::Testing.inline! do
      SlaOnStatusChange.new.perform(status_id: ticket_status.status_id, status_changed: false)
    end
    assert Account.current.ticket_statuses.find_by_id(ticket_status.id).present?
    Sidekiq::Testing.inline! do
      ModifyTicketStatus.new.perform(status_id: ticket_status.status_id, status_name: ticket_status.name)
    end
    assert_equal Account.current.ticket_statuses.find_by_id(ticket_status.id).present?, false

    # Reverse job trigger
    ticket_status = create_ticket_status
    ticket_status.deleted = true
    ticket_status.save!
    Sidekiq::Testing.inline! do
      ModifyTicketStatus.new.perform(status_id: ticket_status.status_id, status_name: ticket_status.name)
    end
    assert Account.current.ticket_statuses.find_by_id(ticket_status.id).present?
    Sidekiq::Testing.inline! do
      SlaOnStatusChange.new.perform(status_id: ticket_status.status_id, status_changed: false)
    end
    assert_equal Account.current.ticket_statuses.find_by_id(ticket_status.id).present?, false
  ensure
    Account.current.rollback :ticket_field_revamp
  end

  def test_status_should_not_be_deleted_on_all_jobs_completion_tf_revamp_disabled
    ticket_status = create_ticket_status
    ticket_status.deleted = true
    ticket_status.save!
    Sidekiq::Testing.inline! do
      SlaOnStatusChange.new.perform(status_id: ticket_status.status_id, status_changed: false)
    end
    assert Account.current.ticket_statuses.find_by_id(ticket_status.id).present?
    Sidekiq::Testing.inline! do
      ModifyTicketStatus.new.perform(status_id: ticket_status.status_id, status_name: ticket_status.name)
    end
    assert_equal Account.current.ticket_statuses.find_by_id(ticket_status.id).present?, true
  ensure
    ticket_status.destroy
  end

  def test_update_ticket_properties_should_update_ticket_sla_time_to_not_nil_if_status_stops_sla_timer
    ticket_status = create_ticket_status
    ticket = create_ticket(status: ticket_status.status_id)
    ticket_status.update_tickets_properties
    assert_not_equal ticket.reload.ticket_states.sla_timer_stopped_at, nil
  ensure
    ticket_status.destroy
    ticket.destroy
  end

  def test_update_ticket_properties_should_update_ticket_sla_time_to_nil_if_status_does_not_stop_sla_timer
    ticket_status = create_ticket_status(stop_sla_timer: 0)
    ticket = create_ticket(status: ticket_status.status_id)
    ticket.ticket_states.sla_timer_stopped_at = Time.now
    ticket.save
    ticket_status.update_tickets_properties
    assert_equal ticket.reload.ticket_states.sla_timer_stopped_at, nil
  ensure
    ticket_status.destroy
    ticket.destroy
  end
end
