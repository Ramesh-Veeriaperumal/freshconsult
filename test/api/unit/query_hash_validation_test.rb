require_relative '../unit_test_helper'
require_relative '../helpers/ticket_fields_test_helper'

class QueryHashValidationTest < ActionView::TestCase

  include TicketFieldsTestHelper

  def tear_down
    Account.unstub(:current)
    super
  end

  def stub_account
    Account.stubs(:current).returns(Account.first)
  end

  def get_a_custom_field
    @account = Account.current || Account.first.make_current
    @custom_field ||= ((Account.current.ticket_fields_from_cache.select { |tf| tf.default == false }|| []).first || 
      create_custom_field_dropdown)
    Account.reset_current_account
    @account = nil
    @custom_field
  end
  
  def sample_query_params
    {
      condition: 'status', 
      operator: 'is_in',
      type: 'default',
      value: [2]
    }
  end

  def test_missing_attributes
    stub_account
    [:condition, :operator, :value].each do |attribute|
      query_validation = QueryHashValidation.new(sample_query_params.except(attribute))
      refute query_validation.valid?
    end
  end

  def test_invalid_condition
    stub_account
    query = sample_query_params
    query[:condition] = 'sample_condition'
    query_validation = QueryHashValidation.new(query)
    refute query_validation.valid?
    error = query_validation.errors.full_messages
    assert error.include?('Condition is invalid')
  end

  def test_invalid_operator
    stub_account
    query = sample_query_params
    query[:operator] = 'sample_operator'
    query_validation = QueryHashValidation.new(query)
    refute query_validation.valid?
    error = query_validation.errors.full_messages
    assert error.include?('Operator not_included')
  end

  def test_invalid_type
    stub_account
    query = sample_query_params
    query[:type] = 'sample_type'
    query_validation = QueryHashValidation.new(query)
    refute query_validation.valid?
    error = query_validation.errors.full_messages
    assert error.include?('Type not_included')
  end

  def test_condition_custom_field_validity
    stub_account
    query = sample_query_params
    query[:condition] = TicketDecorator.display_name(get_a_custom_field[:name])
    query_validation = QueryHashValidation.new(query)
    assert query_validation.valid?
  end

  def test_valid_operator
    stub_account
    query = sample_query_params
    CustomFilterConstants::OPERATORS.sample(5).each do |operator|
      query[:operator] = operator
      query_validation = QueryHashValidation.new(query)
      assert query_validation.valid?
    end
  end

  def test_valid_type
    stub_account
    query = sample_query_params
    query[:type] = CustomFilterConstants::QUERY_TYPE_OPTIONS.sample
    query_validation = QueryHashValidation.new(query)
    assert query_validation.valid?
  end

  def test_is_in_should_have_array_value
    stub_account
    query = sample_query_params
    query[:value] = '1,2'
    query_validation = QueryHashValidation.new(query)
    refute query_validation.valid?
    assert query_validation.errors.full_messages.include?('Value datatype_mismatch')
  end

  def test_due_by_should_have_array_value
    stub_account
    query = sample_query_params
    query[:condition] = 'due_by'
    query[:operator] = 'due_by_op'
    query[:value] = '1,2'
    query_validation = QueryHashValidation.new(query)
    refute query_validation.valid?
    assert query_validation.errors.full_messages.include?('Value datatype_mismatch')
  end

  def test_valid_query_hash
    stub_account
    query_validation = QueryHashValidation.new(sample_query_params)
    assert query_validation.valid?
  end

end
