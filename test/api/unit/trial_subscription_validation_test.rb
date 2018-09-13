require_relative '../unit_test_helper'

class TrialSubscriptionsValidationTest < ActionView::TestCase

  def test_trial_plan_presence
    trial_subscription_validation = TrialSubscriptionsValidation.new({}, nil)
    refute trial_subscription_validation.valid?(:create)
    errors = trial_subscription_validation.errors.full_messages
    assert errors.include?("Trial plan can't be blank")
  end

  def test_trial_plan_datatype
    trial_subscription_validation = TrialSubscriptionsValidation.new({ trial_plan: Faker::Number.number(2).to_i }, nil)
    refute trial_subscription_validation.valid?(:create)
    errors = trial_subscription_validation.errors.full_messages
    assert errors.include?('Trial plan datatype_mismatch')
  end
end
