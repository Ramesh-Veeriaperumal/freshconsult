require_relative '../../test_helper'
require_relative '../../../../spec/support/wf_filter_helper'
require_relative '../../../../spec/support/account_helper'
require 'faker'

class TicketFilterTransformationTest < ActiveSupport::TestCase
  include AccountHelper
  include WfFilterHelper
  include TagTestHelper

  def tag
    @tag = create_tag(create_account)
    @tag
  end

  def sample_filter_conditions
    {
      wf_type: Helpdesk::Filters::CustomTicketFilter,
      wf_match: 'and',
      wf_model: 'Helpdesk::Ticket',
      wf_order: 'created_at',
      wf_order_type: 'desc',
      data_hash: [
        { 'condition' => 'internal_agent_id', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => '2,3' },
        { 'condition' => 'requester_id', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => '12,13' },
        { 'condition' => 'requester_id', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => [12, 13] },
        { 'condition' => 'owner_id', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => '122,123' },
        { 'condition' => 'owner_id', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => ['122', '123'] },
        { 'condition' => 'any_group_id', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => '6,7' },
        { 'condition' => 'responder_id', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => '0,-1' },
        { 'condition' => 'responder_id', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => 0 },
        { 'condition' => 'group_id', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => '0,3' },
        { 'condition' => 'status', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => '2' },
        { 'condition' => 'priority', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => '1,4' },
        { 'condition' => 'source', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => '2,3' },
        { 'condition' => 'helpdesk_schema_less_tickets.product_id', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => '2143,2144' },
        { 'condition' => 'helpdesk_tags.name', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => tag.name },
        { 'condition' => 'ticket_type', 'operator' => 'is_in', 'ff_name' => 'default', 'value' => 'Question,Duplicate,None' },
        { 'condition' => 'flexifields.ffs_02', 'operator' => 'is_in', 'ff_name' => "cf_custom_drop_down_#{Account.current.id}", 'value' => 'First Choice,Second Choice' },
        { 'condition' => 'created_at', 'operator' => 'is_greater_than', 'ff_name' => 'default', 'value' => '25 MAR 2020 - 22 APR 2020' },
        { 'condition' => 'created_at', 'operator' => 'is_greater_than', 'ff_name' => 'default', 'value' => ['15'] },
        { 'condition' => 'created_at', 'operator' => 'is_greater_than', 'ff_name' => 'default', 'value' => ['240'] },
        { 'condition' => 'created_at', 'operator' => 'is_greater_than', 'ff_name' => 'default', 'value' => 'yesterday' },
        { 'condition' => 'created_at', 'operator' => 'is_greater_than', 'ff_name' => 'default', 'value' => 'week' },
        { 'condition' => 'created_at', 'operator' => 'is_greater_than', 'ff_name' => 'default', 'value' => 'last_week' },
        { 'condition' => 'created_at', 'operator' => 'is_greater_than', 'ff_name' => 'default', 'value' => 'month' },
        { 'condition' => 'created_at', 'operator' => 'is_greater_than', 'ff_name' => 'default', 'value' => 'last_month' },
        { 'condition' => 'created_at', 'operator' => 'is_greater_than', 'ff_name' => 'default', 'value' => 'two_months' },
        { 'condition' => 'created_at', 'operator' => 'is_greater_than', 'ff_name' => 'default', 'value' => 'six_months' },
        { 'condition' => 'due_by', 'operator' => 'due_by_op', 'ff_name' => 'default', 'value' => '1,2,3,4,5,6,7,8' },
        { 'condition' => 'due_by', 'operator' => 'due_by_op', 'ff_name' => 'default', 'value' => 1 },
        { 'condition' => 'flexifields.ff_date01', 'operator' => 'is', 'ff_name' => "cf_fsm_appointment_start_time_#{Account.current.id}", 'value' => 'none' },
        { 'condition' => 'flexifields.ff_date01', 'operator' => 'is', 'ff_name' => "cf_fsm_appointment_start_time_#{Account.current.id}", 'value' => 'next_week' },
        { 'condition' => 'flexifields.ff_date02', 'operator' => 'is', 'ff_name' => "cf_fsm_appointment_end_time_#{Account.current.id}", 'value' => { from: '12 MAR 2020', to: '20 MAR 2020' } }
      ]
    }
  end

  def transformed_filters_hash
    {
      operator: 'AND',
      conditions: [
        { field: 'internal_agent_id', is_in: [2, 3], type: 'number', default_field: true },
        { field: 'requester_id', is_in: [12, 13], type: 'number', default_field: true },
        { field: 'requester_id', is_in: [12, 13], type: 'number', default_field: true },
        { field: 'company_id', is_in: [122, 123], type: 'number', default_field: true },
        { field: 'company_id', is_in: [122, 123], type: 'number', default_field: true },
        { field: 'any_group_id', is_in: [6, 7], type: 'number', default_field: true },
        { field: 'responder_id', is_in: [0, -1], type: 'number', default_field: true },
        { field: 'responder_id', is_in: [0], type: 'number', default_field: true },
        { field: 'group_id', is_in: [0, 3], type: 'number', default_field: true },
        { field: 'status', is_in: [2], type: 'number', default_field: true },
        { field: 'priority', is_in: [1, 4], type: 'number', default_field: true },
        { field: 'source', is_in: [2, 3], type: 'number', default_field: true },
        { field: 'product_id', is_in: [2143, 2144], type: 'number', default_field: true },
        { field: 'tag_id', is_in: [@tag.id], type: 'number', default_field: true },
        { field: 'ticket_type', is_in: ['Question', 'Duplicate', 'None'], type: 'string', default_field: true },
        { field: "cf_custom_drop_down_#{Account.current.id}", is_in: ['First Choice', 'Second Choice'], type: 'string', default_field: false },
        { field: 'created_at', gte: Time.zone.parse('2020-03-25').utc.iso8601, lt: Time.zone.parse('2020-04-22').end_of_day.utc.iso8601, type: 'date_time', default_field: true },
        { field: 'created_at', gte: 'now-15m', type: 'date_time', default_field: true },
        { field: 'created_at', gte: 'now-4h', type: 'date_time', default_field: true },
        { field: 'created_at', gte: 'now-1d/d', lt: 'now/d', type: 'date_time', default_field: true },
        { field: 'created_at', gte: 'now/w', lt: 'now+1w/w', type: 'date_time', default_field: true },
        { field: 'created_at', gte: 'now-1w/w', lt: 'now/w', type: 'date_time', default_field: true },
        { field: 'created_at', gte: 'now/M', lt: 'now+1M/M', type: 'date_time', default_field: true },
        { field: 'created_at', gte: 'now-1M/M', lt: 'now/M', type: 'date_time', default_field: true },
        { field: 'created_at', gte: 'now-2M/M', lt: 'now/M', type: 'date_time', default_field: true },
        { field: 'created_at', gte: 'now-6M/M', lt: 'now/M', type: 'date_time', default_field: true },
        { field: 'due_by', is_in: [{ lt: 'now' }, { gte: 'now/d', lt: 'now+1d/d' }, { gte: 'now+1d/d', lt: 'now+2d/d' }, { gte: 'now', lt: 'now+8h' }, { gte: 'now', lt: 'now+4h' }, { gte: 'now', lt: 'now+2h' }, { gte: 'now', lt: 'now+1h' }, { gte: 'now', lt: 'now+30m' }], type: 'date_time', default_field: true },
        { field: 'due_by', is_in: [{ lt: 'now' }], type: 'date_time', default_field: true },
        { field: "cf_fsm_appointment_start_time_#{Account.current.id}", eq: 'none', type: 'date_time', default_field: false },
        { field: "cf_fsm_appointment_start_time_#{Account.current.id}", gte: 'now+1w/w', lt: 'now+2w/w', type: 'date_time', default_field: false },
        { field: "cf_fsm_appointment_end_time_#{Account.current.id}", gte: '2020-03-12T00:00:00Z', lt: '2020-03-20T23:59:59Z', type: 'date_time', default_field: false }

      ]
    }
  end

  def test_central_publish_on_create_update_and_destroy
    account = create_account
    CentralPublisher::Worker.jobs.clear
    account.stubs(:ticket_filters_central_publish_enabled?).returns(true)
    filter = create_filter(WfFilterHelper::PARAMS1)
    assert_equal 1, CentralPublisher::Worker.jobs.size
    CentralPublisher::Worker.jobs.clear
    filter.data[:data_hash][0]['value'] = '0,2'
    filter.save
    assert_equal 1, CentralPublisher::Worker.jobs.size
    CentralPublisher::Worker.jobs.clear
    account.ticket_filters.find(filter.id).destroy
    assert_equal 1, CentralPublisher::Worker.jobs.size
  ensure
    account.stubs(:ticket_filters_central_publish_enabled?).returns(false)
  end

  def test_transformation_of_filters
    result_hash = Helpdesk::Filters::TransformTicketFilter.new.process_args(sample_filter_conditions)
    result_hash.must_match_json_expression(transformed_filters_hash)
  end

  private

    def create_account
      (Account.first.presence || create_test_account).make_current
    end
end
