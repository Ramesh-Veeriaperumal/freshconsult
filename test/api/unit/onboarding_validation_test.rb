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

  def test_presence_for_test_email_forwarding_attempt
    send_to = Faker::Internet.email
    onboarding_validation = OnboardingValidation.new({ send_to: send_to }, nil)
    refute onboarding_validation.valid?(:test_email_forwarding)
  end

  def test_numericality_for_test_email_forwarding_attempt
    attempt = Faker::Number.number(1).to_i
    send_to = Faker::Internet.email
    onboarding_validation = OnboardingValidation.new({ attempt: attempt, send_to: send_to }, nil)
    if attempt >= 1 && attempt <= OnboardingConstants::TEST_FORWARDING_ATTEMPT_THRESHOLD
      assert onboarding_validation.valid?(:test_email_forwarding)
    else
      refute onboarding_validation.valid?(:test_email_forwarding)
    end
  end

  def test_presence_for_test_email_forwarding_email
    attempt = Faker::Number.between(1, 4)
    onboarding_validation = OnboardingValidation.new({ attempt: attempt }, nil)
    refute onboarding_validation.valid?(:test_email_forwarding)
  end

  def test_format_of_test_email_forwarding_email
    attempt = Faker::Number.between(1, 4)
    send_to = Faker::Name.name
    onboarding_validation = OnboardingValidation.new({ attempt: attempt, send_to: send_to }, nil)
    refute onboarding_validation.valid?(:test_email_forwarding)
  end

  def test_format_of_test_email_forwarding_email
    attempt = Faker::Number.between(1, 4)
    send_to = Faker::Internet.email
    onboarding_validation = OnboardingValidation.new({ attempt: attempt, send_to: send_to }, nil)
    assert onboarding_validation.valid?(:test_email_forwarding)
  end

  def test_valid_email_for_admin_email
    onboarding_validation = OnboardingValidation.new({ admin_email: Faker::Internet.email }, nil)
    assert onboarding_validation.valid?(:anonymous_to_trial)
  end

  def test_invalid_email_for_admin_email
    onboarding_validation = OnboardingValidation.new({ admin_email: Faker::Lorem.word }, nil)
    refute onboarding_validation.valid?(:anonymous_to_trial)
  end

  def test_empty_value_for_admin_email
    onboarding_validation = OnboardingValidation.new({ admin_email: '' }, nil)
    refute onboarding_validation.valid?(:anonymous_to_trial)
  end
end
