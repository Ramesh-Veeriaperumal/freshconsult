require_relative '../api/unit_test_helper'

class ThresholdApiHelperTest < ActionView::TestCase
  include HelpdeskReports::Helper::ThresholdApiHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    User.stubs(:current).returns(User.first)
  end

  def teardown
    Account.unstub(:current)
    User.unstub(:current)
    super
  end

  def create_basic_params
    {
      filter_id: 1
    }.stringify_keys!
  end

  def create_str_params
    {
      filter_id: 'one'
    }.stringify_keys!
  end

  def get_json_params(transformed)
    { _json: transformed }
  end

  def get_parsed_result
    @no_data = true
    @processed_result = { k: '1' }
  end

  def sample_threshold_response(busy_hr)
    { metric: nil, metric_type: 'avg', avg: 0, level2: 0, level1: 0, busy_hr: busy_hr }
  end

  def get_default_filters
    [{ 'condition' => 'status', 'operator' => 'is_in', 'value' => 2 },
     { 'condition' => 'responder_id', 'operator' => 'is_in', 'value' => '-1,0' },
     { 'condition' => 'spam', 'operator' => 'is', 'value' => false },
     { 'condition' => 'deleted', 'operator' => 'is', 'value' => false },
     { 'condition' => 'group_id', 'operator' => 'is_in', 'value' => '-1,0' },
     { 'condition' => 'owner_id', 'operator' => 'is_in', 'value' => '-1,0' },
     { 'condition' => 'helpdesk_schema_less_tickets.product_id', 'operator' => 'is_in', 'value' => '-1,0' },
     { 'condition' => 'source', 'operator' => 'is_in', 'value' => '8,9,10' },
     { 'condition' => 'ticket_type', 'operator' => 'is_in', 'value' => 'Question' },
     { 'condition' => 'helpdesk_tags.name', 'operator' => 'is_in', 'value' => 'ab' }]
  end

  def test_transform_threshold_request
    Helpdesk::Filters::CustomTicketFilter.any_instance.stubs(:data).returns(data_hash: [{ ff_name: 'custom', condition: 'equals.to', value: 'test_value' }.stringify_keys!])
    ThresholdApiHelperTest.any_instance.stubs(:params).returns(create_basic_params)
    transformed = transform_threshold_request
    assert_equal 'TICKET', transformed.first[:model]
  end

  def test_transform_threshold_request_str_params
    Account.any_instance.stubs(:ticket_filters).returns([Helpdesk::Filters::CustomTicketFilter.new])
    Helpdesk::Filters::CustomTicketFilter.any_instance.stubs(:default_filter).returns(get_default_filters)
    Helpdesk::Filters::CustomTicketFilter.any_instance.stubs(:data).returns(data_hash: [{ ff_name: 'custom', condition: 'equals.to', value: 'test_value' }.stringify_keys!])
    ThresholdApiHelperTest.any_instance.stubs(:params).returns(create_str_params)
    transformed = transform_threshold_request
    assert_equal 'TICKET', transformed.first[:model]
  end

  def test_get_threshold
    HelpdeskReportsConfig.stubs(:find).returns(HelpdeskReportsConfig.new)
    HelpdeskReportsConfig.any_instance.stubs(:get_config).returns(days_limit: 1, warning_pc: 1, danger_pc: 1, request_bacth_size: 1)
    MemcacheKeys.stubs(:cache).returns(true)
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    Helpdesk::Filters::CustomTicketFilter.any_instance.stubs(:data).returns(data_hash: [{ ff_name: 'custom', condition: 'equals.to', value: 'test_value' }.stringify_keys!])
    ThresholdApiHelperTest.any_instance.stubs(:params).returns(create_basic_params)
    transformed = transform_threshold_request
    ThresholdApiHelperTest.any_instance.stubs(:params).returns(get_json_params(transformed))
    ThresholdApiHelperTest.any_instance.stubs(:build_and_execute).returns([{ result: [{ h: 2 }.stringify_keys!] }.stringify_keys!])
    ThresholdApiHelperTest.any_instance.stubs(:parse_result).returns(get_parsed_result)
    threshold = get_threshold
    assert_equal sample_threshold_response(2), threshold
  end

  def test_get_threshold_no_result
    HelpdeskReportsConfig.stubs(:find).returns(HelpdeskReportsConfig.new)
    HelpdeskReportsConfig.any_instance.stubs(:get_config).returns(days_limit: 1, warning_pc: 1, danger_pc: 1, request_bacth_size: 1)
    MemcacheKeys.stubs(:cache).returns(true)
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    Helpdesk::Filters::CustomTicketFilter.any_instance.stubs(:data).returns(data_hash: [{ ff_name: 'custom', condition: 'equals.to', value: 'test_value' }.stringify_keys!])
    ThresholdApiHelperTest.any_instance.stubs(:params).returns(create_basic_params)
    transformed = transform_threshold_request
    ThresholdApiHelperTest.any_instance.stubs(:params).returns(get_json_params(transformed))
    ThresholdApiHelperTest.any_instance.stubs(:build_and_execute).returns([{ result: [] }.stringify_keys!])
    ThresholdApiHelperTest.any_instance.stubs(:parse_result).returns(get_parsed_result)
    threshold = get_threshold
    assert_equal sample_threshold_response(0), threshold
  end
end
