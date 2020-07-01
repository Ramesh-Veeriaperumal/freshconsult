require_relative '../unit_test_helper'

class CustomerImportValidationTest < ActionView::TestCase

  def self.fixture_path
    File.join(Rails.root, 'test/api/fixtures/')
  end

  def tear_down
    Account.unstub(:current)
    super
  end

  def test_mandatory_fields_for_create
    customer_import_validation = create_customer_import_validation
    assert !customer_import_validation.valid?(:create)
    assert_equal(customer_import_validation.errors.full_messages.length, 2) 
    assert customer_import_validation.errors.full_messages.include?("File Mandatory attribute missing")
    assert customer_import_validation.errors.full_messages.include?("Fields missing_field")
  end

  def test_blank_fields_param
    customer_import_validation = create_customer_import_validation({ fields: {}, file: fixture_file_upload('files/contacts_import.csv', 'text/csv', :binary) })
    assert !customer_import_validation.valid?(:create)
    assert_equal(customer_import_validation.errors.full_messages.length, 1)
    assert customer_import_validation.errors.full_messages.include?("Fields blank")
  end

  def test_with_valid_fields
    customer_import_validation = create_customer_import_validation({ fields: { name: 2, email: 7 }, file: fixture_file_upload('files/contacts_import.csv', 'text/csv', :binary) })
    assert customer_import_validation.valid?(:create)
  end

  def test_with_invalid_fields
    customer_import_validation = create_customer_import_validation({ fields: { invalid_field: 2, email: 7 }, file: fixture_file_upload('files/contacts_import.csv', 'text/csv', :binary) })
    refute customer_import_validation.valid?(:create)
  end

  def test_with_invalid_fields_values
    customer_import_validation = create_customer_import_validation({ fields: { name: 'sample', email: 7 }, file: fixture_file_upload('files/contacts_import.csv', 'text/csv', :binary) })
    refute customer_import_validation.valid?(:create)
  end

  def test_uploading_invalid_file_format
    customer_import_validation = create_customer_import_validation({ fields: { name: 2, email: 7 }, file: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) })
    assert !customer_import_validation.valid?(:create)
    assert customer_import_validation.errors.full_messages.include?("File It should be in the 'CSV' format")
  end

  def test_uploading_valid_file_with_invalid_file_content
    customer_import_validation = create_customer_import_validation(fields: { name: 2, email: 7 }, file: fixture_file_upload('files/invalid_contacts_import.csv', 'text/csv', :binary))
    refute customer_import_validation.valid?(:create)
    assert customer_import_validation.errors.full_messages.include?("File It should contain only valid 'CSV' contents")
  end

  def test_mandatory_fields_for_create_company
    customer_import_validation = create_customer_import_validation({}, 'company')
    assert !customer_import_validation.valid?(:create)
    assert_equal(customer_import_validation.errors.full_messages.length, 2)
    assert customer_import_validation.errors.full_messages.include?('File Mandatory attribute missing')
    assert customer_import_validation.errors.full_messages.include?('Fields missing_field')
  end

  def test_blank_fields_param_company
    customer_import_validation = create_customer_import_validation({ fields: {}, file: fixture_file_upload('files/companies_import.csv', 'text/csv', :binary) }, 'company')
    assert !customer_import_validation.valid?(:create)
    assert_equal(customer_import_validation.errors.full_messages.length, 1)
    assert customer_import_validation.errors.full_messages.include?('Fields blank')
  end

  def test_with_valid_fields_company
    customer_import_validation = create_customer_import_validation({ fields: { name: 0, note: 2 }, file: fixture_file_upload('files/companies_import.csv', 'text/csv', :binary) }, 'company')
    assert customer_import_validation.valid?(:create)
  end

  def test_with_invalid_fields_company
    customer_import_validation = create_customer_import_validation({ fields: { invalid_field: 0, note: 2 }, file: fixture_file_upload('files/companies_import.csv', 'text/csv', :binary) }, 'company')
    refute customer_import_validation.valid?(:create)
  end

  def test_with_invalid_fields_values_company
    customer_import_validation = create_customer_import_validation({ fields: { name: 'sample', note: 2 }, file: fixture_file_upload('files/companies_import.csv', 'text/csv', :binary) }, 'company')
    refute customer_import_validation.valid?(:create)
  end

  def test_uploading_invalid_file_format_company
    customer_import_validation = create_customer_import_validation({ fields: { name: 0, note: 2 }, file: fixture_file_upload('files/attachment.txt', 'plain/text', :binary) }, 'company')
    assert !customer_import_validation.valid?(:create)
    assert customer_import_validation.errors.full_messages.include?("File It should be in the 'CSV' format")
  end

  def test_uploading_valid_file_with_invalid_file_content_company
    customer_import_validation = create_customer_import_validation({ fields: { name: 0, note: 2 }, file: fixture_file_upload('files/invalid_companies_import.csv', 'text/csv', :binary) }, 'company')
    refute customer_import_validation.valid?(:create)
    assert customer_import_validation.errors.full_messages.include?("File It should contain only valid 'CSV' contents")
  end

  private

    def create_customer_import_validation(request_param = {}, import_type = 'contact')
      Account.stubs(:current).returns(Account.first)
      params_hash = request_param.merge(import_type: import_type)
      CustomerImportValidation.new(params_hash, nil)
    end

end