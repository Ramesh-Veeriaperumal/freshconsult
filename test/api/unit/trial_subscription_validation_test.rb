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

  def test_usage_metrics_for_features_too_long_error
    trial_subscription_validation = TrialSubscriptionsValidation.new({ 
      features: (UsageMetrics::Features::FEATURES_LIST + 
        UsageMetrics::Features::FEATURES_TRUE_BY_DEFAULT) }, nil)
    refute trial_subscription_validation.valid?(:usage_metrics)
    errors = trial_subscription_validation.errors.full_messages
    assert errors.include?('Features too_long')
  end

  def test_usage_metrics_for_invalid_feature
    trial_subscription_validation = TrialSubscriptionsValidation.new({ 
      features: [ :test_feature ] }, nil)
    refute trial_subscription_validation.valid?(:usage_metrics)
    errors = trial_subscription_validation.errors.full_messages
    assert errors.include?('Features not_included')
  end

  def test_usage_metrics_for_valid_feature
    trial_subscription_validation = TrialSubscriptionsValidation.new({ 
      features: [:parent_child_tickets_toggle, :scenario_automations] }, nil)
    assert trial_subscription_validation.valid?(:usage_metrics)
  end
end
