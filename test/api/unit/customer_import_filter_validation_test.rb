require_relative '../unit_test_helper'

class CustomerImportFilterValidationTest < ActionView::TestCase
  def test_valid
    status_fields = CustomerImportConstants::ALLOWED_STATUS_PARAMS
    import_filter = CustomerImportFilterValidation.new(status: status_fields.join(', '))
    assert import_filter.valid?
  end

  def test_invalid_filters
    invalid_include_list = ['completed', Faker::Lorem.word, Faker:: Lorem.word]
    controller_params = { status: invalid_include_list.join(', ') }
    import_filter = CustomerImportFilterValidation.new(controller_params)
    refute import_filter.valid?
    errors = import_filter.errors.full_messages
    assert errors.include?('Status not_included')
  end
end
