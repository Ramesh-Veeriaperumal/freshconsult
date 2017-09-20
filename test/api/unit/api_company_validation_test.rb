require_relative '../unit_test_helper'

class ApiCompanyValidationTest < ActionView::TestCase
  def tear_down
    Account.unstub(:current)
    Account.any_instance.unstub(:company_form)
    CompanyForm.unstub(:custom_company_fields)
    super
  end

  def test_domains_comma_invalid
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:company_form).returns(CompanyForm.new)
    CompanyForm.any_instance.stubs(:custom_company_fields).returns([])
    controller_params = { 'name' => 'test', domains: ['comma,test'] }
    item = nil
    company = ApiCompanyValidation.new(controller_params, item)
    refute company.valid?(:create)
    errors = company.errors.full_messages
    assert errors.include?('Domains special_chars_present')
    assert_equal({ domains: { chars: ',' }, name: {} }, company.error_options)
  end

  def test_domains_comma_valid
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:company_form).returns(CompanyForm.new)
    CompanyForm.any_instance.stubs(:custom_company_fields).returns([])
    controller_params = { 'name' => 'comma test', domains: ['comma', 'test'] }
    item = nil
    company = ApiCompanyValidation.new(controller_params, item)
    assert company.valid?(:create)
  end

  def test_domains_multiple_errors
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:company_form).returns(CompanyForm.new)
    CompanyForm.any_instance.stubs(:custom_company_fields).returns([])
    controller_params = { 'name' => 'test', domains: 'comma,test' }
    item = nil
    company = ApiCompanyValidation.new(controller_params, item)
    refute company.valid?(:create)
    errors = company.errors.full_messages
    assert errors.include?('Domains datatype_mismatch')
    assert errors.count == 1
  end

  def test_complex_fields_with_nil
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:company_form).returns(CompanyForm.new)
    CompanyForm.any_instance.stubs(:custom_company_fields).returns([])
    controller_params = { 'name' => 'test', domains: nil, custom_fields: nil }
    company = ApiCompanyValidation.new(controller_params, nil)
    refute company.valid?
    errors = company.errors.full_messages
    assert errors.include?('Domains datatype_mismatch')
    assert errors.include?('Custom fields datatype_mismatch')
    Account.unstub(:current)
  end

  def test_complex_fields_with_invalid_datatype
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:company_form).returns(CompanyForm.new)
    CompanyForm.any_instance.stubs(:custom_non_dropdown_fields).returns([company_field('cf_custom_text')])
    controller_params = { 'name' => 'test', 'custom_fields' => { 'cf_custom_text' => 123 } }
    company = ApiCompanyValidation.new(controller_params, nil)
    refute company.valid?
    errors = company.errors.full_messages
    assert errors.include?('Cf custom text datatype_mismatch')
    Account.unstub(:current)
  end

  def test_complex_fields_with_valid_datatype
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:company_form).returns(CompanyForm.new)
    CompanyForm.any_instance.stubs(:custom_non_dropdown_fields).returns([company_field('cf_custom_text')])
    controller_params = { 'name' => 'test', 'custom_fields' => { 'cf_custom_text' => 'text' } }
    company = ApiCompanyValidation.new(controller_params, nil)
    assert company.valid?
    Account.unstub(:current)
  end

  private

    def company_field(name)
      company_field = CompanyField.new
      company_field.name = name
      company_field.field_type = 'custom_text'
      company_field
    end
end
