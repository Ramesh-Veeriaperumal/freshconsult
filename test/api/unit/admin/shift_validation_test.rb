require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../../test/api/helpers/shift_test_helper'

class Admin::ShiftValidationTest < ActionView::TestCase
  include ShiftTestHelper

  # valid tests
  VALID_SHIFTS.each_with_index do |params, index|
    define_method "test_valid_shift_param_#{index}" do
      Account.stubs(:current).returns(Account.first)
      validation = shift_validation_class.new(params, Account.current.agents.pluck_all(:user_id))
      assert validation.valid?
    end
  end

  # invalid tests
  INVALID_SHIFTS.each_with_index do |params, index|
    define_method "test_invalid_shift_param_#{index}" do
      Account.stubs(:current).returns(Account.first)
      validation = shift_validation_class.new(params, Account.current.agents.pluck_all(:user_id))
      assert validation.invalid?
    end
  end

  def shift_validation_class
    'Admin::ShiftValidation'.constantize
  end
end
