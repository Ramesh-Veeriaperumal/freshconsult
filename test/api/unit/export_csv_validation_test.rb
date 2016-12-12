require_relative '../unit_test_helper'

class ExportCsvValidationTest < ActionView::TestCase
  def test_export_with_empty_params
    export_csv_valdiation = ExportCsvValidation.new({}, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Request select_a_field')

    controller_params = { default_fields: [], custom_fields: [] }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Request select_a_field')
  end

  def test_datatypes_for_export
    controller_params = { default_fields: "test", custom_fields: "test" }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Default fields datatype_mismatch')
    assert errors.include?('Custom fields datatype_mismatch')
  end

  def test_invalid_fields_for_export
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_fields).returns([contact_field("name"), contact_field("job_title")])
    ContactForm.any_instance.stubs(:custom_fields).returns([contact_field("cf_custom_text")])
    controller_params = { default_fields: ["invalid_field"], custom_fields: ["invalid_field"] }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Default fields not_included')
    assert errors.include?('Custom fields not_included')
    Account.unstub(:current)
    Account.any_instance.unstub(:contact_form)
    ContactForm.any_instance.unstub(:default_fields)
    ContactForm.any_instance.unstub(:custom_fields)
  end

  def test_validation_success
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_fields).returns([contact_field("name"), contact_field("job_title")])
    ContactForm.any_instance.stubs(:custom_fields).returns([contact_field("cf_custom_text")])
    controller_params = { default_fields: ["name"], custom_fields: ["custom_text"] }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    assert export_csv_valdiation.valid?
    Account.unstub(:current)
    Account.any_instance.unstub(:contact_form)
    ContactForm.any_instance.unstub(:default_fields)
    ContactForm.any_instance.unstub(:custom_fields)
  end

  private
    def contact_field(name)
      contact_field = ContactField.new
      contact_field.name = name
      contact_field
    end
end
