require_relative '../unit_test_helper'

class CompanyFilterValidationTest < ActionView::TestCase
  
  def test_invalid_filters
    invalid_include_list = [Faker::Lorem.word, Faker:: Lorem.word]
    controller_params = { 'include' => invalid_include_list.join(', '), 'letter' => '1' }
    company_validation = CompanyFilterValidation.new(controller_params)
    refute company_validation.valid?
    errors = company_validation.errors.full_messages
    assert errors.include?('Include not_included')
    assert errors.include?('Letter not_included')
  end

  def test_valid_filters
    controller_params = { 'include' => 'contacts_count, sla_policies', 'letter' => 'A' }
    company_validation = CompanyFilterValidation.new(controller_params)
    assert company_validation.valid?
  end
end
