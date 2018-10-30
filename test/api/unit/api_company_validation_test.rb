require_relative '../unit_test_helper'

class ApiCompanyValidationTest < ActionView::TestCase
  def teardown
    Account.unstub(:current)
    Account.any_instance.unstub(:company_form)
    Account.any_instance.unstub(:tam_default_fields_enabled?)
    CompanyForm.unstub(:custom_company_fields)
    CompanyForm.unstub(:default_company_fields)
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

  def test_tam_default_fields_without_feature
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:company_form).returns(CompanyForm.new)
    Account.any_instance.stubs(:tam_default_fields_enabled?).returns(false)
    controller_params = { 'name' => 'test', 'health_score' => 'At risk', 'account_tier' => 'Premium',
                          'industry' => 'Media', 'renewal_date' => '2017-12-11' }
    company = ApiCompanyValidation.new(controller_params, nil)
    refute company.valid?
    errors = company.errors.full_messages
    assert errors.include?('Health score require_feature_for_attribute')
    assert errors.include?('Account tier require_feature_for_attribute')
    assert errors.include?('Industry require_feature_for_attribute')
    assert errors.include?('Renewal date require_feature_for_attribute')
    Account.unstub(:current)
  end

  def test_tam_default_fields_with_invalid_data_types
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:company_form).returns(CompanyForm.new)
    Account.any_instance.stubs(:tam_default_fields_enabled?).returns(true)
    controller_params = { 'name' => 'test', 'health_score' => 3, 'account_tier' => 4,
                          'industry' => 5, 'renewal_date' => 'test string' }
    company = ApiCompanyValidation.new(controller_params, nil)
    refute company.valid?
    errors = company.errors.full_messages
    assert errors.include?('Health score datatype_mismatch')
    assert errors.include?('Account tier datatype_mismatch')
    assert errors.include?('Industry datatype_mismatch')
    assert errors.include?('Renewal date invalid_date')
    Account.unstub(:current)
  end

  def test_tam_default_fields_with_required
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:company_form).returns(CompanyForm.new)
    Account.any_instance.stubs(:tam_default_fields_enabled?).returns(true)
    CompanyForm.any_instance.stubs(:default_company_fields).returns([
      default_required_company_field('health_score'),
      default_required_company_field('account_tier'),
      default_required_company_field('industry'),
      default_required_company_field('renewal_date')])
    controller_params = { 'name' => 'test'}
    company = ApiCompanyValidation.new(controller_params, nil)
    refute company.valid?
    errors = company.errors.full_messages
    assert errors.include?('Health score datatype_mismatch')
    assert errors.include?('Account tier datatype_mismatch')
    assert errors.include?('Industry datatype_mismatch')
    assert errors.include?('Renewal date invalid_date')
    assert_equal({ name: {},
        health_score: { expected_data_type: String, code: :missing_field },
        account_tier: { expected_data_type: String, code: :missing_field },
        industry:     { expected_data_type: String, code: :missing_field },
        renewal_date: { accepted: :"yyyy-mm-dd", code: :missing_field }}, 
        company.error_options)
    Account.unstub(:current)
  end

  def test_tam_default_fields_with_proper_values
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:company_form).returns(CompanyForm.new)
    Account.any_instance.stubs(:tam_default_fields_enabled?).returns(true)
    CompanyForm.any_instance.stubs(:default_company_fields).returns([
      default_required_company_field('health_score'),
      default_required_company_field('account_tier'),
      default_required_company_field('industry'),
      default_required_company_field('renewal_date')])
    controller_params = { 'name' => 'test', 'health_score' => 'At risk', 'account_tier' => 'Premium',
                          'industry' => 'Media', 'renewal_date' => '2017-12-11'}
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

    def default_required_company_field(name)
      company_field = CompanyField.new
      company_field.name = name
      company_field.field_type = "default_#{name}"
      company_field.required_for_agent = true
      company_field
    end
end
