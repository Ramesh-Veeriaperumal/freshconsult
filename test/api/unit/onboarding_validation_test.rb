require_relative '../unit_test_helper'

class OnboardingValidationTest < ActionView::TestCase
  def test_empty_body
    onboarding_validation = OnboardingValidation.new({}, nil)
    refute onboarding_validation.valid?(:update_activation_email)
    errors = onboarding_validation.errors.full_messages
    assert errors.include?("New email can't be blank")
  end

  def test_empty_new_email
    onboarding_validation = OnboardingValidation.new({ new_email: '' }, nil)
    refute onboarding_validation.valid?(:update_activation_email)
    errors = onboarding_validation.errors.full_messages
    assert errors.include?("New email can't be blank")
  end

  def test_invalid_new_email
    onboarding_validation = OnboardingValidation.new({ new_email: Faker::Lorem.word }, nil)
    refute onboarding_validation.valid?(:update_activation_email)
    errors = onboarding_validation.errors.full_messages
    assert errors.include?('New email invalid_format')
  end

  def test_valid_new_email
    onboarding_validation = OnboardingValidation.new({ new_email: Faker::Internet.email }, nil)
    assert onboarding_validation.valid?(:update_activation_email)
  end
end
