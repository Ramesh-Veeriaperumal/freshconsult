require_relative '../../api/unit_test_helper'

class FilterTest < ActiveSupport::TestCase

  def setup
    @data_type_hash_for_wf_filter = { 'bigint' => ['nil', 'numeric', 'numeric_range', 'numeric_delimited'], 'numeric' => ['nil', 'numeric', 'numeric_range', 'numeric_delimited'], 'smallint' => ['nil', 'numeric', 'numeric_range', 'numeric_delimited'], 'integer' => ['nil', 'numeric', 'numeric_range', 'numeric_delimited'], 'int' => ['nil', 'numeric', 'numeric_range', 'numeric_delimited'], 'float' => ['nil', 'numeric', 'numeric_range', 'numeric_delimited'], 'double' => ['nil', 'numeric', 'numeric_range', 'numeric_delimited'], 'timestamp' => ['nil', 'date_time', 'date_time_range', 'single_date'], 'datetime' => ['nil', 'date_time', 'date_time_range', 'single_date'], 'date' => ['nil', 'date', 'date_range'], 'character' => ['nil', 'text', 'text_delimited'], 'varchar' => ['nil', 'text', 'text_delimited'], 'longtext' => ['nil', 'text', 'text_delimited'], 'text' => ['nil', 'text', 'text_delimited'], 'text[]' => ['nil', 'text', 'text_delimited'], 'bytea' => ['nil', 'text', 'text_delimited'], 'boolean' => ['nil', 'boolean'], 'tinyint' => ['nil', 'boolean'], 'helpdesk_tickets' => { 'text' => ['text'], 'dropdown' => ['text_delimited'], 'due_by' => ['due_by'], 'special_responder' => ['special_responder'], 'boolean' => ['boolean'], 'created_at' => ['created_at'], 'requester' => ['requester'], 'customer' => ['customer'], 'tags' => ['tags'] }, 'freshfone_calls' => { 'datetime' => ['created_at', 'date_time_range'], 'int' => ['numeric', 'numeric_delimited'], 'bigint' => ['numeric', 'numeric_delimited'], 'varchar' => ['text'], 'float' => ['numeric', 'numeric_range'], 'text' => ['text'], 'tinyint' => ['nil', 'boolean'] }, 'json' => ['nil', 'text', 'text_delimited'] }
    @account = Account.first
    @account.make_current
    @agent = @account.agents.first
    @user = @account.users.first
    @user.make_current
    @wf_filter = Wf::Filter.new
    @wf_filter.save
  end

  def test_filter_dup
    @wf_filter = @account.ticket_filters.first
    assert_equal @wf_filter.dup.class, Helpdesk::Filters::CustomTicketFilter
  end

  def test_show_export_options
    @wf_filter = @account.ticket_filters.first
    assert_equal @wf_filter.show_export_options?, true
  end

  def test_show_save_options
    @wf_filter = @account.ticket_filters.first
    assert_equal @wf_filter.show_save_options?, true
  end

  def test_filter_params
    @wf_filter = @account.ticket_filters.first
    @wf_filter.query_hash = [{ 'condition': 'status', 'operator': 'is_in', 'value': '2,3' }]
    assert_equal @wf_filter.key, ''
    assert_equal @wf_filter.format, :html
    assert_empty @wf_filter.fields
    assert_empty @wf_filter.inner_joins
    assert_empty @wf_filter.custom_formats
    assert_equal @wf_filter.model_columns.length, 60
    assert_equal @wf_filter.contains_column?(:priority), true
    assert_equal @wf_filter.default_order, 'created_at'
    assert_equal @wf_filter.default_per_page_options.length, 6
    assert_equal @wf_filter.column_sorted?('id'), false
    assert_equal @wf_filter.per_page_options.length, 6
    assert_equal @wf_filter.match_options.length, 2
    assert_equal @wf_filter.order_type_options.length, 2
    assert_equal @wf_filter.condition_title_for('custom_fields.id'), '> Custom Fields: Id'
    assert_equal @wf_filter.condition_title_for('id'), 'Id'
    assert @wf_filter.condition_options
    assert_not_nil @wf_filter.to_s
    @wf_filter.key = 'tickets'
    assert_equal @wf_filter.key, 'tickets'
    assert_includes @wf_filter.container_by_sql_type('text'), 'text'
    assert_not_nil @wf_filter.sum(:id)
    assert_equal @wf_filter.first_sorted_operator(is: 'true', is_not: 'false'), :is
    assert_includes @wf_filter.operator_options_for('status')[0], 'is_in'
    assert_equal @wf_filter.has_condition?('contains'), false
    assert_empty @wf_filter.remove_all
    assert_not_nil @wf_filter.saved_filters
    assert_nil @wf_filter.reset!
    assert_nil @wf_filter.load_default_filter('bigint')
  end

  def test_filter_params_with_new_entry
    Wf::Config.stubs(:data_types).returns(@data_type_hash_for_wf_filter)
    Wf::Filter.any_instance.stubs(:custom_formats).returns([['pdf', 'pdf']])
    Wf::Filter.any_instance.stubs(:inner_joins).returns([['Helpdesk::Ticket', 'account_id']])
    assert_not_nil @wf_filter.add_default_condition_at(0)
    assert_not_nil @wf_filter.add_default_condition_at(1)
    assert_not_nil @wf_filter.export_formats
    assert_equal @wf_filter.custom_format?, false
    assert_not_nil @wf_filter.definition
    assert_not_nil @wf_filter.results
    assert_equal @wf_filter.joins.length, 1
    assert_not_nil @wf_filter.default_condition_key
    assert_not_nil @wf_filter.default_operator_key('requester_id')
    assert_not_nil @wf_filter.order_model
    assert_not_nil @wf_filter.order_clause
    assert_not_nil @wf_filter.reverse_order_clause
    assert_not_nil @wf_filter.condition_models
    assert_not_nil @wf_filter.debug_sql_conditions
    assert_equal @wf_filter.process_custom_format, ''
    assert_empty @wf_filter.value_options_for('contains')
    assert_equal @wf_filter.valid_format?, false
    assert_not_nil @wf_filter.condition_by_key(:account_id)
    assert_equal @wf_filter.serialize_to_params[:wf_type], 'Wf::Filter'
    assert_not_nil @wf_filter.deserialize_from_params(@wf_filter.serialize_to_params)
    assert_not_nil Wf::Filter.deserialize_from_params(@wf_filter.serialize_to_params)
    assert_not_nil @wf_filter.remove_condition_at(0)
    assert_empty @wf_filter.remove_all
  ensure
    Wf::Config.unstub(:data_types)
    Wf::Filter.any_instance.unstub(:custom_formats)
    Wf::Filter.any_instance.unstub(:inner_joins)
  end

  def test_filter_params_with_required_condition_keys
    Wf::Config.stubs(:data_types).returns(@data_type_hash_for_wf_filter)
    Wf::Filter.any_instance.stubs(:required_condition_keys).returns(['is not'])
    assert_equal @wf_filter.required_conditions_met?, false
    condition_key = @wf_filter.default_condition_key
    condition_operator = @wf_filter.default_operator_key(condition_key)
    assert_not_nil @wf_filter.clone_with_condition(condition_key, condition_operator)
  ensure
    Wf::Config.unstub(:data_types)
    Wf::Filter.any_instance.unstub(:required_condition_keys)
  end

  def test_filter_params_with_order
    Wf::Config.stubs(:data_types).returns(@data_type_hash_for_wf_filter)
    Wf::Filter.any_instance.stubs(:order).returns('Helpdesk::Filters::CustomTicketFilter.id')
    assert_not_nil @wf_filter.reverse_order_clause
    assert_not_nil @wf_filter.order_clause
    assert_not_nil @wf_filter.order_model
  ensure
    Wf::Config.unstub(:data_types)
    Wf::Filter.any_instance.unstub(:order)
  end

  def test_sql_conditions_raises_error
    Wf::Config.stubs(:data_types).returns(@data_type_hash_for_wf_filter)
    @wf_filter.add_default_condition_at(0)
    Wf::Containers::Numeric.any_instance.stubs(:sql_condition).returns(nil)
    assert_raises(Wf::FilterException) do
      @wf_filter.sql_conditions
    end
  ensure
    Wf::Config.unstub(:data_types)
    Wf::Containers::Numeric.any_instance.unstub(:sql_condition)
  end

  def test_condition_with_multi_keys
    Wf::Config.stubs(:data_types).returns(@data_type_hash_for_wf_filter)
    @wf_filter.add_default_condition_at(0)
    Wf::FilterCondition.any_instance.stubs(:key).returns('helpdesk_tickets.account_id')
    assert_includes @wf_filter.condition_models, 'HelpdeskTickets'
  ensure
    Wf::Config.unstub(:data_types)
    Wf::FilterCondition.any_instance.unstub(:key)
  end

  def test_saved_filters_without_including_default
    Wf::Config.stubs(:data_types).returns(@data_type_hash_for_wf_filter)
    Wf::Config.stubs(:user_filters_enabled?).returns(true)
    Wf::Config.stubs(:current_user).returns(@user)
    assert_not_nil @wf_filter.saved_filters(false)
  ensure
    Wf::Config.unstub(:data_types)
    Wf::Config.unstub(:user_filters_enabled?)
    Wf::Config.unstub(:current_user)
  end

  def test_saved_filters_without_current_user_set
    Wf::Config.stubs(:data_types).returns(@data_type_hash_for_wf_filter)
    Wf::Config.stubs(:user_filters_enabled?).returns(true)
    Wf::Config.stubs(:current_user).returns(nil)
    assert_not_nil @wf_filter.saved_filters(false)
  ensure
    Wf::Config.unstub(:data_types)
    Wf::Config.unstub(:user_filters_enabled?)
    Wf::Config.unstub(:current_user)
  end

  def test_saved_filters_with_multiple_default_filters
    Wf::Config.stubs(:data_types).returns(@data_type_hash_for_wf_filter)
    Wf::Filter.any_instance.stubs(:default_filters).returns([['Selected filter', '-1'], ['Selected test filter', '-3']])
    assert_not_nil @wf_filter.saved_filters
  ensure
    Wf::Config.unstub(:data_types)
    Wf::Filter.any_instance.unstub(:default_filters)
  end

  def test_filter_params_with_multiple_conditions
    Wf::Config.stubs(:data_types).returns(@data_type_hash_for_wf_filter)
    Wf::Filter.any_instance.stubs(:default_filter_if_empty).returns(@wf_filter.id)
    Wf::Filter.any_instance.stubs(:default_filter_conditions).returns(['is', 'not'])
    assert_not_nil @wf_filter.handle_empty_filter!
    Wf::Filter.any_instance.stubs(:default_filter_conditions).returns([['is', 'not']])
    Wf::Filter.any_instance.stubs(:add_condition).returns(true)
    assert_nothing_raised do
      @wf_filter.load_default_filter(@wf_filter.id)
    end
  ensure
    Wf::Config.unstub(:data_types)
    Wf::Filter.any_instance.unstub(:default_filter_if_empty)
    Wf::Filter.any_instance.unstub(:default_filter_conditions)
    Wf::Filter.any_instance.unstub(:add_condition)
  end

  def test_deserialize_filter_params
    Wf::Config.stubs(:data_types).returns(@data_type_hash_for_wf_filter)
    Wf::Filter.any_instance.stubs(:required_conditions_met?).returns(false)
    filter_params = @wf_filter.serialize_to_params
    filter_params = filter_params.merge(wf_export_fields: 'id,account_id', wf_export_format: 'html', 'wf_c0' => 'account_id', 'wf_o0' => 'is', 'wf_v0_0' => '1', wf_submitted: 'true')
    new_filter =  Wf::Filter.deserialize_from_params(filter_params)
    assert_not_nil new_filter.sql_conditions
  ensure
    Wf::Config.unstub(:data_types)
    Wf::Filter.any_instance.unstub(:required_conditions_met?)
  end

  def test_debug_conditions_with_different_params
    conditons = [0, ['helpdesk_tickets.account_id = ?  AND  helpdesk_tickets.account_id = ? '], Time.zone.today, Time.zone.now, 0, 'test']
    Wf::Config.stubs(:data_types).returns(@data_type_hash_for_wf_filter)
    assert_equal @wf_filter.debug_conditions(conditons).length, 6
  end
end
