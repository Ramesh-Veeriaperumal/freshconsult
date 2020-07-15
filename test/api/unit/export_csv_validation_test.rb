require_relative '../unit_test_helper'

class ExportCsvValidationTest < ActionView::TestCase
  def test_contact_export_with_empty_params
    export_csv_valdiation = ExportCsvValidation.new({}, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Request select_a_field')

    controller_params = { fields: {}, export_type: 'contact' }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Fields blank')

    controller_params = { fields: { default_fields: [], custom_fields: [], export_type: 'contact' } }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Request select_a_field')
  end

  def test_company_export_with_empty_params
    export_csv_valdiation = ExportCsvValidation.new({}, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Request select_a_field')

    controller_params = { fields: {}, export_type: 'company' }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Fields blank')

    controller_params = { fields: { default_fields: [], custom_fields: [], export_type: 'company' } }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Request select_a_field')
  end

  def test_contact_export_with_more_than_max_fields
    def_fields =  Faker::Lorem.words(ApiConstants::MAX_CUSTOMER_EXPORT_FIELDS)
    cust_fields = Faker::Lorem.words(ApiConstants::MAX_CUSTOMER_EXPORT_FIELDS)
    ExportCsvValidation.any_instance.stubs(:default_field_names).returns(def_fields)
    ExportCsvValidation.any_instance.stubs(:custom_field_names).returns(cust_fields)
    controller_params = { fields: { default_fields: def_fields, custom_fields: cust_fields, export_type: 'contact' } }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Request fields_limit_exceeded')
  end

  def test_company_export_with_more_than_max_fields
    def_fields =  Faker::Lorem.words(ApiConstants::MAX_CUSTOMER_EXPORT_FIELDS)
    cust_fields = Faker::Lorem.words(ApiConstants::MAX_CUSTOMER_EXPORT_FIELDS)
    ExportCsvValidation.any_instance.stubs(:default_field_names).returns(def_fields)
    ExportCsvValidation.any_instance.stubs(:custom_field_names).returns(cust_fields)
    controller_params = { fields: { default_fields: def_fields, custom_fields: cust_fields, export_type: 'company' } }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Request fields_limit_exceeded')
  end

  def test_datatypes_for_contact_export
    controller_params = { fields: { default_fields: 'test', custom_fields: 'test', export_type: 'contact' } }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Default fields datatype_mismatch')
    assert errors.include?('Custom fields datatype_mismatch')

    controller_params = { fields: 'test', export_type: 'contact' }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Fields datatype_mismatch')
  end

  def test_datatypes_for_company_export
    controller_params = { fields: { default_fields: 'test', custom_fields: 'test', export_type: 'company' } }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Default fields datatype_mismatch')
    assert errors.include?('Custom fields datatype_mismatch')

    controller_params = { fields: 'test', export_type: 'company' }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Fields datatype_mismatch')
  end

  def test_invalid_fields_for_contact_export
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([contact_field('name'), contact_field('job_title')])
    ContactForm.any_instance.stubs(:custom_contact_fields).returns([contact_field('cf_custom_text')])
    controller_params = { fields: { default_fields: ['invalid_field'], custom_fields: ['invalid_field'], export_type: 'contact' } }
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

  def test_invalid_fields_for_company_export
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:company_form).returns(CompanyForm.new)
    CompanyForm.any_instance.stubs(:default_company_fields).returns([company_field('name'), company_field('domains')])
    CompanyForm.any_instance.stubs(:custom_company_fields).returns([company_field('cf_custom_text')])
    controller_params = { fields: { default_fields: ['invalid_field'], custom_fields: ['invalid_field'], export_type: 'company' } }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    refute export_csv_valdiation.valid?
    errors = export_csv_valdiation.errors.full_messages
    assert errors.include?('Default fields not_included')
    assert errors.include?('Custom fields not_included')
    Account.unstub(:current)
    Account.any_instance.unstub(:company_form)
    CompanyForm.any_instance.unstub(:default_fields)
    CompanyForm.any_instance.unstub(:custom_fields)
  end

  def test_validation_success_for_contact_export
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([contact_field('name'), contact_field('job_title')])
    ContactForm.any_instance.stubs(:custom_contact_fields).returns([contact_field('cf_custom_text')])
    controller_params = { fields: { default_fields: ['name'], custom_fields: ['custom_text'], export_type: 'contact' } }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    assert export_csv_valdiation.valid?
    Account.unstub(:current)
    Account.any_instance.unstub(:contact_form)
    ContactForm.any_instance.unstub(:default_fields)
    ContactForm.any_instance.unstub(:custom_fields)
  end

  def test_validation_success_for_company_export
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:company_form).returns(CompanyForm.new)
    CompanyForm.any_instance.stubs(:default_company_fields).returns([company_field('name'), company_field('domains')])
    CompanyForm.any_instance.stubs(:custom_company_fields).returns([company_field('cf_custom_text')])
    controller_params = { fields: { default_fields: ['name'], custom_fields: ['custom_text'], export_type: 'company' } }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    assert export_csv_valdiation.valid?
    Account.unstub(:current)
    Account.any_instance.unstub(:company_form)
    CompanyForm.any_instance.unstub(:default_fields)
    CompanyForm.any_instance.unstub(:custom_fields)
  end

  def test_validation_success_for_contact_export_with_tags
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    ContactForm.any_instance.stubs(:default_contact_fields).returns([contact_field('name'), contact_field('tag_names')])
    controller_params = { fields: { default_fields: ['name', 'tag_names'], custom_fields: [], export_type: 'contact' } }
    export_csv_valdiation = ExportCsvValidation.new(controller_params, nil)
    assert export_csv_valdiation.valid?
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:contact_form)
    ContactForm.any_instance.unstub(:default_fields)
  end

  private

    def contact_field(name)
      contact_field = ContactField.new
      contact_field.name = name
      contact_field
    end

    def company_field(name)
      company_field = CompanyField.new
      company_field.name = name
      company_field
    end
end
