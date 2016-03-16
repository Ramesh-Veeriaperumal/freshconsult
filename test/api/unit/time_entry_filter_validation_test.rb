require_relative '../unit_test_helper'

class TimeEntryFilterValidationTest < ActionView::TestCase
  def tear_down
    Account.unstub(:current)
    Account.any_instance.unstub(:companies)
    ActiveRecord::Relation.any_instance.unstub(find_by_id)
    Account.any_instance.unstub(:agents_from_cache)
    super
  end

  def test_valid
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:companies).returns(Company.scoped)
    ActiveRecord::Relation.any_instance.stubs(:find_by_id).returns(true)
    Account.any_instance.stubs(:agents_from_cache).returns([Agent.new(user_id: 1)])
    time_entry_filter = TimeEntryFilterValidation.new(company_id: 1, agent_id: 1, billable: true,
                                                      executed_after: Time.zone.now.iso8601, executed_before: Time.zone.now.iso8601)
    result = time_entry_filter.valid?
    assert result
  end

  def test_nil_value
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:companies).returns(Company.scoped)
    ActiveRecord::Relation.any_instance.stubs(:find_by_id).returns(true)
    Account.any_instance.stubs(:agents_from_cache).returns([Agent.new(user_id: 1)])
    time_entry_filter = TimeEntryFilterValidation.new(company_id: nil, agent_id: nil, billable: nil,
                                                      executed_after: nil, executed_before: nil)
    refute time_entry_filter.valid?
    error = time_entry_filter.errors.full_messages
    assert error.include?('Executed after invalid_date')
    assert error.include?('Agent datatype_mismatch')
    assert error.include?('Executed before invalid_date')
    assert error.include?('Company datatype_mismatch')
    assert error.include?('Billable datatype_mismatch')
    assert_equal({ billable: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: 'Null Type' },
                   executed_after: { accepted: :'combined date and time ISO8601' },
                   executed_before: { accepted: :'combined date and time ISO8601' },
                   agent_id: { expected_data_type: :'Positive Integer', prepend_msg: :input_received, given_data_type: 'Null Type' },
                   company_id: { expected_data_type: :'Positive Integer', prepend_msg: :input_received, given_data_type: 'Null Type' } }, time_entry_filter.error_options)
  end
end
