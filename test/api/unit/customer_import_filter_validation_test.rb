require_relative '../unit_test_helper'

class CustomerImportFilterValidationTest < ActionView::TestCase
  
  def test_mandatory_fields_for_index
    customer_import_filter_validation = create_customer_import_filter_validation({})
    assert !customer_import_filter_validation.valid?
    assert_equal customer_import_filter_validation.errors.full_messages[0], "Type missing_field"
  end

  def test_invalid_type_field_value
  	customer_import_filter_validation = create_customer_import_filter_validation({ type: Faker::Lorem.word })
  	assert !customer_import_filter_validation.valid?
  	assert_equal customer_import_filter_validation.errors.full_messages[0], "Type not_included"
  end

  def test_valid_type_field
  	customer_import_filter_validation = create_customer_import_filter_validation({ type: "contact" })
  	assert customer_import_filter_validation.valid?
  	customer_import_filter_validation = create_customer_import_filter_validation({ type: "company" })
  	assert customer_import_filter_validation.valid?
  end

  def create_customer_import_filter_validation(param)
  	Account.stubs(:current).returns(Account.first)
    CustomerImportFilterValidation.new(param)
  end
end