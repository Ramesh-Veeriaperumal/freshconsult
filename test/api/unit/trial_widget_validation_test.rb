require_relative '../unit_test_helper'

class TrialWidgetValidationTest < ActionView::TestCase

  def test_step_not_included_in_the_account_setup_list
    trial_widget_validator = TrialWidgetValidation.new({ step: Faker::Name.name.downcase }, nil)
    refute trial_widget_validator.valid?(:complete_step)
    errors = trial_widget_validator.errors.full_messages
    assert errors.include?('Step is not included in the list')
  end

  def test_step_not_string
    trial_widget_validator = TrialWidgetValidation.new({ step: Faker::Number.number(10).to_i }, nil)
    refute trial_widget_validator.valid?(:complete_step)
    errors = trial_widget_validator.errors.full_messages
    assert errors.include?('Step datatype_mismatch')
  end

  def test_valid_step
    n_steps = Account::SETUP_KEYS.count
    trial_widget_validator = TrialWidgetValidation.new({ step: Account::SETUP_KEYS[Random.rand(n_steps)] }, nil)
    assert trial_widget_validator.valid?(:complete_step)
  end

  def test_goal_not_array
    n_steps = Account::SETUP_KEYS.count
    trial_widget_validator = TrialWidgetValidation.new({ goals: Account::SETUP_KEYS[Random.rand(n_steps)] }, nil)
    refute trial_widget_validator.valid?(:complete_step)
    errors = trial_widget_validator.errors.full_messages
    assert errors.include?('Goals is invalid')
  end

  def test_goal_not_string
    n_steps = Account::SETUP_KEYS.count
    trial_widget_validator = TrialWidgetValidation.new({ goals: [Account::SETUP_KEYS[Random.rand(n_steps)], Faker::Number.number(10)] }, nil)
    refute trial_widget_validator.valid?(:complete_step)
    errors = trial_widget_validator.errors.full_messages
    assert errors.include?('Goals is invalid')
  end

  def test_goal_not_included_in_the_onboarding_goals
    n_steps = Account::SETUP_KEYS.count
    n_goals = Account::ONBOARDING_V2_GOALS.count
    trial_widget_validator = TrialWidgetValidation.new({ goals: [Account::SETUP_KEYS[Random.rand(n_steps)], Account::ONBOARDING_V2_GOALS[Random.rand(n_goals)]] }, nil)
    refute trial_widget_validator.valid?(:complete_step)
    errors = trial_widget_validator.errors.full_messages
    assert errors.include?('Goals is invalid')
  end

  def test_valid_goal
    n_steps = Account::ONBOARDING_V2_GOALS.count
    trial_widget_validator = TrialWidgetValidation.new({ goals: [Account::ONBOARDING_V2_GOALS[Random.rand(n_steps)]] }, nil)
    assert trial_widget_validator.valid?(:complete_step)
  end
end
