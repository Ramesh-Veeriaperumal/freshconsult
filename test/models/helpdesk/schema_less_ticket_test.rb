# frozen_string_literal: true

require_relative '../test_helper'
['account_helper.rb', 'user_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }
['shared_ownership_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

class SchemaLessTicketTest < ActiveSupport::TestCase
  include AccountHelper
  include TicketsTestHelper
  include ModelsGroupsTestHelper
  include SharedOwnershipTestHelper

  def setup
    super
    before_all
    @ticket = create_ticket
  end

  @@before_all_run = false

  def before_all
    @account = Account.current
    return if @@before_all_run

    @agent = add_test_agent(@account)
    @@before_all_run = true
  end

  def test_agent_assigned_flag_is_set
    @ticket.attributes = { responder_id: @agent.id }
    @ticket.save
    assert_equal true, @ticket.reports_hash['agent_assigned_flag']
    assert_nil @ticket.reports_hash['agent_reassigned_flag']
  ensure
    @ticket.destroy
  end

  def test_agent_reassigned_flag_is_set
    @ticket.attributes = { responder_id: @agent.id }
    @ticket.save
    reassigned_agent = add_test_agent(@account)
    assert_equal true, @ticket.reports_hash['agent_assigned_flag']
    assert_nil @ticket.reports_hash['agent_reassigned_flag']
    @ticket.attributes = { responder_id: reassigned_agent.id }
    @ticket.save
    assert_equal true, @ticket.reports_hash['agent_assigned_flag']
    assert_equal true, @ticket.reports_hash['agent_reassigned_flag']
  ensure
    @ticket.destroy
  end

  def test_agent_reassigned_flag_should_be_active_when_set_agent_assigned_flag_is_called_again
    @ticket.attributes = { responder_id: @agent.id }
    @ticket.save
    assert_equal true, @ticket.reports_hash['agent_assigned_flag']
    assert_nil @ticket.reports_hash['agent_reassigned_flag']
    reassigned_agent = add_test_agent(@account)
    @ticket.attributes = { responder_id: reassigned_agent.id }
    @ticket.save
    assert_equal true, @ticket.reports_hash['agent_assigned_flag']
    assert_equal true, @ticket.reports_hash['agent_reassigned_flag']
    @ticket.attributes = { responder_id: @agent.id }
    @ticket.save
    assert_equal true, @ticket.reports_hash['agent_reassigned_flag']
  ensure
    @ticket.destroy
  end

  def test_agent_resassigned_flag_and_agent_assigned_flag_must_be_unset_when_agent_is_unassigned
    @ticket.attributes = { responder_id: @agent.id }
    @ticket.save
    assert_equal true, @ticket.reports_hash['agent_assigned_flag']
    assert_nil @ticket.reports_hash['agent_reassigned_flag']
    reassigned_agent = add_test_agent(@account)
    @ticket.attributes = { responder_id: reassigned_agent.id }
    @ticket.save
    assert_equal true, @ticket.reports_hash['agent_assigned_flag']
    assert_equal true, @ticket.reports_hash['agent_reassigned_flag']
    @ticket.attributes = { responder_id: nil }
    @ticket.save
    assert_nil @ticket.reports_hash['agent_assigned_flag']
    assert_equal true, @ticket.reports_hash['agent_reassigned_flag']
    @ticket.attributes = { responder_id: @agent.id }
    @ticket.save
    assert_equal true, @ticket.reports_hash['agent_assigned_flag']
  ensure
    @ticket.destroy
  end

  def test_group_assigned_flag_is_set
    group = create_group(@account)
    @ticket.attributes = { group_id: group.id, group: group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['group_assigned_flag']
    assert_nil @ticket.reports_hash['group_reassigned_flag']
  ensure
    @ticket.destroy
  end

  def test_group_reassigned_flag_is_set
    group = create_group(@account)
    @ticket.attributes = { group_id: group.id, group: group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['group_assigned_flag']
    assert_nil @ticket.reports_hash['group_reassigned_flag']
    reassigned_group = create_group(@account)
    @ticket.attributes = { group_id: reassigned_group.id, group: reassigned_group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['group_assigned_flag']
    assert_equal true, @ticket.reports_hash['group_reassigned_flag']
  ensure
    @ticket.destroy
  end

  def test_group_reassigned_flag_should_be_active_when_set_group_assigned_flag_is_called_again
    group = create_group(@account)
    @ticket.attributes = { group_id: group.id, group: group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['group_assigned_flag']
    assert_nil @ticket.reports_hash['group_reassigned_flag']
    reassigned_group = create_group(@account)
    @ticket.attributes = { group_id: reassigned_group.id, group: reassigned_group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['group_assigned_flag']
    assert_equal true, @ticket.reports_hash['group_reassigned_flag']
    @ticket.attributes = { group_id: group.id, group: group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['group_reassigned_flag']
  ensure
    @ticket.destroy
  end

  def test_group_resassigned_flag_and_group_assigned_flag_must_be_unset_when_group_is_unassigned
    group = create_group(@account)
    @ticket.attributes = { group_id: group.id, group: group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['group_assigned_flag']
    assert_nil @ticket.reports_hash['group_reassigned_flag']
    reassigned_group = create_group(@account)
    @ticket.attributes = { group_id: reassigned_group.id, group: reassigned_group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['group_assigned_flag']
    assert_equal true, @ticket.reports_hash['group_reassigned_flag']
    @ticket.attributes = { group_id: nil, group: nil }
    @ticket.save
    assert_equal nil, @ticket.reports_hash['group_assigned_flag']
    @ticket.attributes = { group_id: group.id, group: group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['group_assigned_flag']
  ensure
    @ticket.destroy
  end

  def test_internal_group_assigned_flag_is_set
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    initialize_internal_agent_with_default_internal_group(permission = 3)
    @ticket = create_ticket({ status: @status.status_id, responder_id: nil, internal_agent_id: @internal_agent.id }, nil, @internal_group)
    assert_equal true, @ticket.reports_hash['internal_group_assigned_flag']
    assert_nil @ticket.reports_hash['internal_group_reassigned_flag']
  ensure
    Account.any_instance.unstub(:shared_ownership_enabled?)
    @ticket.destroy
  end

  def test_internal_group_reassigned_flag_is_set
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    initialize_internal_agent_with_default_internal_group(permission = 3)
    @ticket = create_ticket({ status: @status.status_id, responder_id: nil, internal_agent_id: @internal_agent.id }, nil, @internal_group)
    assert_equal true, @ticket.reports_hash['internal_group_assigned_flag']
    assert_nil @ticket.reports_hash['internal_group_reassigned_flag']
    add_another_group_to_status
    @ticket.attributes = { internal_group_id: @another_internal_group.id, internal_group: @another_internal_group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['internal_group_assigned_flag']
    assert_equal true, @ticket.reports_hash['internal_group_reassigned_flag']
    initialize_internal_agent_with_custom_internal_group
    @ticket.attributes = { internal_group_id: @internal_group.id, internal_group: @internal_group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['internal_group_reassigned_flag']
  ensure
    Account.any_instance.unstub(:shared_ownership_enabled?)
    @ticket.destroy
  end

  def test_internal_group_resassigned_flag_and_internal_group_assigned_flag_must_be_unset_when_internal_group_is_unassigned
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    initialize_internal_agent_with_default_internal_group(permission = 3)
    @ticket = create_ticket({ status: @status.status_id, responder_id: nil, internal_agent_id: @internal_agent.id }, nil, @internal_group)
    assert_equal true, @ticket.reports_hash['internal_group_assigned_flag']
    assert_nil @ticket.reports_hash['internal_group_reassigned_flag']
    add_another_group_to_status
    @ticket.attributes = { internal_group_id: @another_internal_group.id, internal_group: @another_internal_group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['internal_group_assigned_flag']
    assert_equal true, @ticket.reports_hash['internal_group_reassigned_flag']
    @ticket.attributes = { internal_group_id: nil, internal_group: nil }
    @ticket.save
    assert_nil @ticket.reports_hash['internal_group_assigned_flag']
    initialize_internal_agent_with_custom_internal_group
    @ticket.attributes = { internal_group_id: @internal_group.id, internal_group: @internal_group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['internal_group_assigned_flag']
  ensure
    @ticket.destroy
    Account.any_instance.unstub(:shared_ownership_enabled?)
  end

  def test_internal_agent_assigned_flag_is_set
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    initialize_internal_agent_with_default_internal_group(permission = 3)
    @ticket = create_ticket({ status: @status.status_id, responder_id: nil, internal_agent_id: @internal_agent.id }, nil, @internal_group)
    assert_equal true, @ticket.reports_hash['internal_agent_assigned_flag']
    assert_nil @ticket.reports_hash['internal_agent_reassigned_flag']
  ensure
    Account.any_instance.unstub(:shared_ownership_enabled?)
  end

  def test_internal_agent_reassigned_flag_is_set
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    initialize_internal_agent_with_default_internal_group(permission = 3)
    @ticket = create_ticket({ status: @status.status_id, responder_id: nil, internal_agent_id: @internal_agent.id }, nil, @internal_group)
    assert_equal true, @ticket.reports_hash['internal_agent_assigned_flag']
    assert_nil @ticket.reports_hash['internal_agent_reassigned_flag']
    initialize_internal_agent_with_default_internal_group(permission = 3)
    @ticket.attributes = { internal_agent_id: @internal_agent.id, internal_group: @internal_group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['internal_agent_assigned_flag']
    assert_equal true, @ticket.reports_hash['internal_agent_reassigned_flag']
  ensure
    @ticket.destroy
    Account.any_instance.unstub(:shared_ownership_enabled?)
  end

  def test_internal_agent_reassigned_flag_should_be_active_when_set_internal_agent_assigned_flag_is_called_again
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    initialize_internal_agent_with_default_internal_group(permission = 3)
    @ticket = create_ticket({ status: @status.status_id, responder_id: nil, internal_agent_id: @internal_agent.id }, nil, @internal_group)
    assert_equal true, @ticket.reports_hash['internal_agent_assigned_flag']
    assert_nil @ticket.reports_hash['internal_agent_reassigned_flag']
    initialize_internal_agent_with_default_internal_group(permission = 3)
    @ticket.attributes = { internal_agent_id: @internal_agent.id, internal_group: @internal_group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['internal_agent_assigned_flag']
    assert_equal true, @ticket.reports_hash['internal_agent_reassigned_flag']
    initialize_internal_agent_with_default_internal_group(permission = 3)
    @ticket.attributes = { internal_agent_id: @internal_agent.id, internal_group: @internal_group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['internal_agent_reassigned_flag']
  ensure
    @ticket.destroy
    Account.any_instance.unstub(:shared_ownership_enabled?)
  end

  def test_internal_agent_resassigned_flag_and_internal_agent_assigned_flag_must_be_unset_when_internal_agent_is_unassigned
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    initialize_internal_agent_with_default_internal_group(permission = 3)
    @ticket = create_ticket({ status: @status.status_id, responder_id: nil, internal_agent_id: @internal_agent.id }, nil, @internal_group)
    assert_equal true, @ticket.reports_hash['internal_agent_assigned_flag']
    assert_nil @ticket.reports_hash['internal_agent_reassigned_flag']
    initialize_internal_agent_with_default_internal_group(permission = 3)
    @ticket.attributes = { internal_agent_id: @internal_agent.id, internal_group: @internal_group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['internal_agent_assigned_flag']
    assert_equal true, @ticket.reports_hash['internal_agent_reassigned_flag']
    @ticket.attributes = { internal_agent_id: nil }
    @ticket.save
    assert_nil @ticket.reports_hash['internal_agent_assigned_flag']
    initialize_internal_agent_with_default_internal_group(permission = 3)
    @ticket.attributes = { internal_agent_id: @internal_agent.id, internal_group: @internal_group }
    @ticket.save
    assert_equal true, @ticket.reports_hash['internal_agent_assigned_flag']
  ensure
    @ticket.destroy
    Account.any_instance.unstub(:shared_ownership_enabled?)
  end
end
