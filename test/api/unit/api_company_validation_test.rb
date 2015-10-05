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
end
