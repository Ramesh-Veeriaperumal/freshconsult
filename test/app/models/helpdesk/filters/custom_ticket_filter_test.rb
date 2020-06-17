require_relative '../../../../test_helper'
require_relative '../../../../core/helpers/account_test_helper'

class Helpdesk::Filters::CustomTicketFilterTest < ActionView::TestCase
  include AccountTestHelper
  include QueryHashHelper

  def setup
    @account = Account.first.presence || create_test_account
    @user = Account.current.technicians.first.make_current
  end

  def test_open_status_in_conditions_with_array
    Account.current.launch(:wf_comma_filter_fix)
    filter_params = {
      data_hash: [{ 'condition' => 'status', 'operator' => 'is_in', 'ff_name' => '', 'value' => [0, 1] }],
      custom_ticket_filter: {
        visibility: {
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
          user_id: @user.id
        }
      }
    }
    ticket_filter = create_filter(nil, filter_params)
    assert ticket_filter.open_status_in_conditions?
  ensure
    Account.current.rollback(:wf_comma_filter_fix)
  end

  def test_open_status_in_conditions_with_string
    filter_params = {
      data_hash: [{ 'condition' => 'status', 'operator' => 'is_in', 'ff_name' => '', 'value' => '0,1' }],
      custom_ticket_filter: {
        visibility: {
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me],
          user_id: @user.id
        }
      }
    }
    ticket_filter = create_filter(nil, filter_params)
    assert ticket_filter.open_status_in_conditions?
  end

  def test_dynamic_filter_with_agent_string
    Account.current.launch(:wf_comma_filter_fix)
    filter_params = {
      data_hash: [{ 'condition' => 'responder_id', 'operator' => 'is_in', 'ff_name' => '', 'value' => '0' }],
      custom_ticket_filter: {
        visibility: {
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          user_id: @user.id
        }
      }
    }
    ticket_filter = create_filter(nil, filter_params)
    assert ticket_filter.send(:dynamic_filter?)
  ensure
    Account.current.rollback(:wf_comma_filter_fix)
  end

  def test_dynamic_filter_with_agent_array
    Account.current.launch(:wf_comma_filter_fix)
    filter_params = {
      data_hash: [{ 'condition' => 'responder_id', 'operator' => 'is_in', 'ff_name' => '', 'value' => [0] }],
      custom_ticket_filter: {
        visibility: {
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          user_id: @user.id
        }
      }
    }
    ticket_filter = create_filter(nil, filter_params)
    assert ticket_filter.send(:dynamic_filter?)
  ensure
    Account.current.rollback(:wf_comma_filter_fix)
  end

  def test_dynamic_filter_with_internal_agent_string
    Account.current.launch(:wf_comma_filter_fix)
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    filter_params = {
      data_hash: [{ 'condition' => 'internal_group_id', 'operator' => 'is_in', 'ff_name' => '', 'value' => '0' }],
      custom_ticket_filter: {
        visibility: {
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          user_id: @user.id
        }
      }
    }
    ticket_filter = create_filter(nil, filter_params)
    assert ticket_filter.send(:dynamic_filter?)
  ensure
    Account.any_instance.unstub(:shared_ownership_enabled?)
    Account.current.rollback(:wf_comma_filter_fix)
  end

  def test_dynamic_filter_with_internal_agent_array
    Account.current.launch(:wf_comma_filter_fix)
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    filter_params = {
      data_hash: [{ 'condition' => 'internal_agent_id', 'operator' => 'is_in', 'ff_name' => '', 'value' => [0] }],
      custom_ticket_filter: {
        visibility: {
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          user_id: @user.id
        }
      }
    }
    ticket_filter = create_filter(nil, filter_params)
    assert ticket_filter.send(:dynamic_filter?)
  ensure
    Account.any_instance.unstub(:shared_ownership_enabled?)
    Account.current.rollback(:wf_comma_filter_fix)
  end

  def test_dynamic_filter_with_group_string_string
    Account.current.launch(:wf_comma_filter_fix)
    filter_params = {
      data_hash: [{ 'condition' => 'group_id', 'operator' => 'is_in', 'ff_name' => '', 'value' => '0' }],
      custom_ticket_filter: {
        visibility: {
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          user_id: @user.id
        }
      }
    }
    ticket_filter = create_filter(nil, filter_params)
    assert ticket_filter.send(:dynamic_filter?)
  ensure
    Account.current.rollback(:wf_comma_filter_fix)
  end

  def test_dynamic_filter_with_group_string_array
    Account.current.launch(:wf_comma_filter_fix)
    filter_params = {
      data_hash: [{ 'condition' => 'group_id', 'operator' => 'is_in', 'ff_name' => '', 'value' => [0] }],
      custom_ticket_filter: {
        visibility: {
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          user_id: @user.id
        }
      }
    }
    ticket_filter = create_filter(nil, filter_params)
    assert ticket_filter.send(:dynamic_filter?)
  ensure
    Account.current.rollback(:wf_comma_filter_fix)
  end

  def test_dynamic_filter_with_internal_group_string
    Account.current.launch(:wf_comma_filter_fix)
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    filter_params = {
      data_hash: [{ 'condition' => 'internal_group_id', 'operator' => 'is_in', 'ff_name' => '', 'value' => '0' }],
      custom_ticket_filter: {
        visibility: {
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          user_id: @user.id
        }
      }
    }
    ticket_filter = create_filter(nil, filter_params)
    assert ticket_filter.send(:dynamic_filter?)
  ensure
    Account.any_instance.unstub(:shared_ownership_enabled?)
    Account.current.rollback(:wf_comma_filter_fix)
  end

  def test_dynamic_filter_with_internal_group_array
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    Account.current.launch(:wf_comma_filter_fix)
    filter_params = {
      data_hash: [{ 'condition' => 'internal_group_id', 'operator' => 'is_in', 'ff_name' => '', 'value' => [0] }],
      custom_ticket_filter: {
        visibility: {
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          user_id: @user.id
        }
      }
    }
    ticket_filter = create_filter(nil, filter_params)
    assert ticket_filter.send(:dynamic_filter?)
  ensure
    Account.any_instance.unstub(:shared_ownership_enabled?)
    Account.current.rollback(:wf_comma_filter_fix)
  end

  def test_dynamic_filter_with_internal_group_string_without_wf_comma_filter_fix
    Account.current.rollback(:wf_comma_filter_fix)
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)
    filter_params = {
      data_hash: [{ 'condition' => 'internal_group_id', 'operator' => 'is_in', 'ff_name' => '', 'value' => '0' }],
      custom_ticket_filter: {
        visibility: {
          visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents],
          user_id: @user.id
        }
      }
    }
    ticket_filter = create_filter(nil, filter_params)
    assert ticket_filter.send(:dynamic_filter?)
  ensure
    Account.any_instance.unstub(:shared_ownership_enabled?)
  end
end
