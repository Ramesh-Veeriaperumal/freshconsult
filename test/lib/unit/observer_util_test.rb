# frozen_string_literal: true

require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'note_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')

class ObserverUtilTest < ActiveSupport::TestCase
  include NoteTestHelper
  include CoreTicketsTestHelper

  def setup
    super
    @account = create_test_account if @account.nil?
    @account.make_current
  end

  def create_last_interaction_observer_rule
    rule = @account.observer_rules.find_by_name('add_note_with_last_interaction')
    return rule if rule

    rule = @account.observer_rules.new
    rule.name = 'add_note_with_last_interaction'
    rule.filter_data = []
    rule.condition_data = { performer: { 'type' => '3' }, events: [{ name: 'note_type', value: '--' }], conditions: { any: [{ evaluate_on: ':ticket', name: 'last_interaction', operator: 'is', value: 'test' }] } }
    rule.action_data = [{ name: 'status', value: 5 }]
    rule.save!
    rule
  end

  def create_observer_rule_with_priority_condition
    rule = @account.observer_rules.find_by_name('add_note_with_priority')
    return rule if rule

    rule = @account.observer_rules.new
    rule.name = 'add_note_with_priority'
    rule.filter_data = []
    rule.condition_data = { performer: { 'type' => '3' }, events: [{ name: 'note_type', value: '--' }], conditions: { any: [{ evaluate_on: ':ticket', name: 'priority', operator: 'is', value: '2' }] } }
    rule.action_data = [{ name: 'status', value: 5 }]
    rule.save!
    rule
  end

  def test_original_ticket_attributes_for_last_interaction_observer_rule_with_observer_race_condition_feature
    Account.current.launch(:observer_race_condition_fix)
    note = create_note
    create_last_interaction_observer_rule
    res = note.safe_send(:original_ticket_attributes)
    assert_equal res['last_interaction'], note.id
  ensure
    Account.current.rollback(:observer_race_condition_fix)
  end

  def test_original_ticket_attributes_for_last_interaction_observer_rule_on_ticket_update_with_observer_race_condition_feature
    Account.current.launch(:observer_race_condition_fix)
    ticket = create_ticket
    create_last_interaction_observer_rule
    res = ticket.safe_send(:original_ticket_attributes)
    # Last interaction must be null as we haven't created note and should not throw exception
    assert_equal res['last_interaction'], nil
  ensure
    Account.current.rollback(:observer_race_condition_fix)
  end

  def test_original_ticket_attributes_for_priority_rule_with_observer_race_condition_feature
    Account.current.launch(:observer_race_condition_fix)
    note = create_note
    create_observer_rule_with_priority_condition
    res = note.safe_send(:original_ticket_attributes)
    ticket = Account.current.tickets.find(note.notable_id)
    assert_equal res['priority'], ticket.priority
  ensure
    Account.current.rollback(:observer_race_condition_fix)
  end

  def test_original_ticket_attributes_without_observer_race_condition_feature
    note = create_note
    create_last_interaction_observer_rule
    res = note.safe_send(:original_ticket_attributes)
    assert_equal res, {}
  end
end
