require_relative '../unit_test_helper'

class CallValidationsTest < ActionView::TestCase
  def test_call_validation_params
    params = { fc_call_id: 1, recording_status: 1 }
    call = Freshcaller::CallValidation.new(params)
    assert_equal true, call.valid?
  end

  def test_call_validation_invalid
    params = {}
    call = Freshcaller::CallValidation.new(params)
    assert_equal false, call.valid?
    assert_equal 'fc_call_id'.to_sym, call.errors.first.first
    assert_equal :missing_field, call.errors.first.last
  end
end
