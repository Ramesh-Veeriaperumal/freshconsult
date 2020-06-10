require_relative '../test_helper'
require Rails.root.join('spec', 'support', 'agent_helper.rb')

class FeatureCheckTest < ActionView::TestCase
  include AgentHelper
  include Redis::OthersRedis
  include Redis::RedisKeys
  include Silkroad::Export::FeatureCheck

  def setup
    super
    @account = Account.first.make_current
    @account.launch(:silkroad_export)
    @account.rollback(:ticket_field_limit_increase)
    @agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 4)
    User.stubs(:current).returns(@agent.user)
    User.current.agent.stubs(:ticket_permission_token).returns(:all_tickets)
    set_others_redis_lpush(SILKROAD_TICKET_FIELDS, 'time_tracked_hours')
    set_others_redis_lpush(SILKROAD_FILTER_CONDITIONS, 'any_group_id')
    set_others_redis_lpush(SILKROAD_FILTER_CONDITIONS, 'cf_fsm_appointment_start_time')
  end

  def teardown
    remove_others_redis_key(SILKROAD_TICKET_FIELDS)
    remove_others_redis_key(SILKROAD_FILTER_CONDITIONS)
    User.current.agent.unstub(:ticket_permission_token)
    User.unstub(:current)
    @account.rollback(:silkroad_export)
  end

  def test_agent_without_global_permission
    User.current.agent.stubs(:ticket_permission_token).returns(:group_tickets)
    assert_equal false, send_to_silkroad?(get_active_export_params)
  ensure
    User.current.agent.unstub(:ticket_permission_token)
  end

  def test_account_without_silkroad_enabled
    @account.rollback(:silkroad_export)
    assert_equal false, send_to_silkroad?(get_active_export_params)
  ensure
    @account.launch(:silkroad_export)
  end

  def test_account_with_ticket_fields_limit_increase_enabled
    @account.launch(:ticket_field_limit_increase)
    assert_equal false, send_to_silkroad?(get_active_export_params)
  ensure
    @account.rollback(:ticket_field_limit_increase)
  end

  def test_params_with_active_fields_and_filters
    assert_equal true, send_to_silkroad?(get_active_export_params)
  end

  def test_params_with_inactive_ticket_fields
    export_params = get_active_export_params
    export_params[:ticket_fields] = { time_tracked_hours: 'Time tracked' }.stringify_keys
    assert_equal false, send_to_silkroad?(export_params)
  end

  def test_params_with_inactive_filter_conditions
    export_params = get_active_export_params
    export_params[:data_hash] = [{ condition: 'any_group_id', operator: 'is_in', value: ['2', '4'] }]
    assert_equal false, send_to_silkroad?(export_params)
  end

  def test_filter_conditions_with_inactive_fsm_fields
    export_params = get_active_export_params
    export_params[:data_hash] = [{ condition: 'group_id', ff_name: 'default' },
                                 { condition: 'flexifields.ffs01', ff_name: 'cf_fsm_appointment_start_time_1_1' }]
    assert_equal false, send_to_silkroad?(export_params)
  end

  def test_filter_conditions_with_active_fsm_fields
    export_params = get_active_export_params
    export_params[:data_hash] = [{ condition: 'group_id', ff_name: 'default' },
                                 { condition: 'flexifields.ffs01', ff_name: 'cf_fsm_appointment_end_time_1_1' }]
    assert_equal true, send_to_silkroad?(export_params)
  end

  def test_params_with_custom_contact_fields
    export_params = get_active_export_params
    export_params[:contact_fields] = { name: 'Full name', cf_contact_field: 'Custom Contact Field' }.stringify_keys
    assert_equal false, send_to_silkroad?(export_params)
  end

  def test_params_with_custom_company_fields
    export_params = get_active_export_params
    export_params[:company_fields] = { name: 'Company name', cf_company_field: 'Custom Company Field' }.stringify_keys
    assert_equal false, send_to_silkroad?(export_params)
  end

  private

    def get_active_export_params
      { ticket_fields: { subject: 'Subject' }.stringify_keys,
        data_hash: [{ condition: 'status', operator: 'is_in', value: ['2'] }],
        contact_fields: { name: 'Full name' }.stringify_keys,
        company_fields: { name: 'Company name' }.stringify_keys }
    end
end
