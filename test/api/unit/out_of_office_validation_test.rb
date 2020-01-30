require_relative '../../../test/api/unit_test_helper'

class OutOfOfficeValidationTest < ActionView::TestCase

  def test_valid_oof_input
    Account.stubs(:current).returns(Account.first)
    params = { start_time: '2018-01-08T12:00:00Z', end_time: '2019-01-08T12:01:00Z' }
    validation = out_of_office_validation_class.new(params)
    assert validation.valid?
  end

  def test_invalid_oof_input_without_start_time
    Account.stubs(:current).returns(Account.first)
    params = { end_time: '2019-01-08T12:01:00Z' }
    validation = out_of_office_validation_class.new(params)
    assert validation.invalid?
  end

  def test_invalid_oof_input_without_end_time
    Account.stubs(:current).returns(Account.first)
    params = { start_time: '2018-01-08T12:00:00Z' }
    validation = out_of_office_validation_class.new(params)
    assert validation.invalid?
  end

  def test_invalid_oof_input_with_start_time_greater_than_end_time
    Account.stubs(:current).returns(Account.first)
    params = { end_time: '2018-01-08T12:00:00Z', start_time: '2019-01-08T12:01:00Z' }
    validation = out_of_office_validation_class.new(params)
    assert validation.invalid?
  end

  def out_of_office_validation_class
    'OutOfOfficeValidation'.constantize
  end
end
