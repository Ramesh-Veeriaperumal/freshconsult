require_relative '../unit_test_helper'

class ParamsHelperTest < ActionView::TestCase
  def test_assign_and_clean_params_with_false_values
    params_hash = {modified: :existing, altered: :current}
    controller_params = {modified: false, altered: false}
    ParamsHelper.assign_and_clean_params(params_hash, controller_params)
    assert_equal({existing: false, current: false}, controller_params)      
  end

  def test_clean_params
    controller_params = {a: 1, b: 2}
    params_to_be_deleted = [:a, :c]
    ParamsHelper.clean_params(params_to_be_deleted, controller_params)
    assert_equal({b: 2}, controller_params) 
  end
end
