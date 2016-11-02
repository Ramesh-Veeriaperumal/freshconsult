require_relative '../unit_test_helper'

class ContactMergeValidationTest < ActionView::TestCase
  def test_invalid_params
    merge_validation = ContactMergeValidation.new({}, nil)
    refute merge_validation.valid?
    errors = merge_validation.errors.full_messages
    assert errors.include?('Primary missing_field')
    assert errors.include?('Target ids missing_field')

    controller_params = {'primary_id' => 'XYZ', 'target_ids' => 'ABC'}
    merge_validation = ContactMergeValidation.new(controller_params, nil)
    refute merge_validation.valid?
    errors = merge_validation.errors.full_messages
    assert errors.include?('Primary datatype_mismatch')
    assert errors.include?('Target ids datatype_mismatch')

    controller_params = {'primary_id' => 1, 'target_ids' => ['ABC']}
    merge_validation = ContactMergeValidation.new(controller_params, nil)
    refute merge_validation.valid?
    errors = merge_validation.errors.full_messages
    assert errors.include?('Target ids array_datatype_mismatch')
  end

  def test_validation_success
    controller_params = {'primary_id' => 1, 'target_ids' => [1, 2, 3]}
    merge_validation = ContactMergeValidation.new(controller_params, nil)
    assert merge_validation.valid?
  end
end
