require_relative '../unit_test_helper'

class CustomerImportValidationTest < ActionView::TestCase

  def self.fixture_path
    File.join(Rails.root, 'test/api/fixtures/')
  end

  def test_mandatory_fields_for_create
    customer_import_validation = create_customer_import_validation
    assert !customer_import_validation.valid?(:create)
    assert_equal(customer_import_validation.errors.full_messages.length, 3) 
    assert customer_import_validation.errors.full_messages.include?("Type missing_field")
    assert customer_import_validation.errors.full_messages.include?("File missing_field")
    assert customer_import_validation.errors.full_messages.include?("Fields missing_field")
  end

  def test_invalid_type_field
    customer_import_validation = create_customer_import_validation({ type: Faker::Lorem.word })
    assert !customer_import_validation.valid?(:create)
    assert customer_import_validation.errors.full_messages.include?("Type not_included")
  end

  def test_blank_fields_param
    customer_import_validation = create_customer_import_validation({ type: "contact", fields: {}, file: fixture_file_upload('files/contacts_import.csv', 'text/csv', :binary) })
    assert !customer_import_validation.valid?(:create)
    assert_equal(customer_import_validation.errors.full_messages.length, 1)
    assert customer_import_validation.errors.full_messages.include?("Fields blank")
  end

  def test_with_valid_fields
    customer_import_validation = create_customer_import_validation({ type: "contact", fields: { name: 2, email: 7 }, file: fixture_file_upload('files/contacts_import.csv', 'text/csv', :binary) })
    assert customer_import_validation.valid?(:create)
  end

  def test_uploading_invalid_file_format
    customer_import_validation = create_customer_import_validation({ type: "contact", fields: { name: 2, email: 7 }, file: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) })
    assert !customer_import_validation.valid?(:create)
    assert customer_import_validation.errors.full_messages.include?("File It should be in the 'CSV' format")
  end

  private

  def create_customer_import_validation(request_param = {})
    Account.stubs(:current).returns(Account.first)
    CustomerImportValidation.new(request_param, nil)
  end

end