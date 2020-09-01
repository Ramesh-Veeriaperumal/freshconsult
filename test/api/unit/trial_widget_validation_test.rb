require_relative '../unit_test_helper'

class TrialWidgetValidationTest < ActionView::TestCase

  def test_step_not_included_in_the_account_setup_list
    trial_widget_validator = TrialWidgetValidation.new({ steps: [Faker::Name.name.downcase] }, nil)
    refute trial_widget_validator.valid?(:complete_step)
    errors = trial_widget_validator.errors.full_messages
    assert errors.include?('Steps not_included')
  end

  def test_step_not_string
    trial_widget_validator = TrialWidgetValidation.new({ steps: Faker::Number.number(10).to_i }, nil)
    refute trial_widget_validator.valid?(:complete_step)
    errors = trial_widget_validator.errors.full_messages
    assert errors.include?('Steps datatype_mismatch')
  end

  def test_valid_step
    n_steps = Account::SETUP_KEYS.count
    trial_widget_validator = TrialWidgetValidation.new({ steps: [Account::SETUP_KEYS[Random.rand(n_steps)]] }, nil)
    assert trial_widget_validator.valid?(:complete_step)
  end

  def test_goal_not_array
    n_steps = Account::SETUP_KEYS.count
    trial_widget_validator = TrialWidgetValidation.new({ goals: Account::SETUP_KEYS[Random.rand(n_steps)] }, nil)
    refute trial_widget_validator.valid?(:complete_step)
    errors = trial_widget_validator.errors.full_messages
    assert errors.include?('Goals datatype_mismatch')
  end

  def test_goal_not_string
    n_steps = Account::SETUP_KEYS.count
    trial_widget_validator = TrialWidgetValidation.new({ goals: [Account::SETUP_KEYS[Random.rand(n_steps)], Faker::Number.number(10).to_i] }, nil)
    refute trial_widget_validator.valid?(:complete_step)
    errors = trial_widget_validator.errors.full_messages
    assert errors.include?('Goals not_included')
  end

  def test_goal_not_included_in_the_onboarding_goals
    n_steps = Account::SETUP_KEYS.count
    n_goals = Account::ONBOARDING_V2_GOALS.count
    trial_widget_validator = TrialWidgetValidation.new({ goals: [Account::SETUP_KEYS[Random.rand(n_steps)], Account::ONBOARDING_V2_GOALS[Random.rand(n_goals)]] }, nil)
    refute trial_widget_validator.valid?(:complete_step)
    errors = trial_widget_validator.errors.full_messages
    assert errors.include?('Goals not_included')
  end

  def test_valid_goal
    n_steps = Account::ONBOARDING_V2_GOALS.count
    trial_widget_validator = TrialWidgetValidation.new({ goals: [Account::ONBOARDING_V2_GOALS[Random.rand(n_steps)]] }, nil)
    assert trial_widget_validator.valid?(:complete_step)
  end

  def test_valid_fsm_goal
    trial_widget_validator = TrialWidgetValidation.new({ goals: ['manage_field_workforce'] }, nil)
    assert trial_widget_validator.valid?(:complete_step)
  end

  def test_freshmarketer_event_name
    trial_widget_validator = TrialWidgetValidation.new({ steps: ['fdesk_tickets_view'] }, nil)
    assert trial_widget_validator.valid?(:complete_step)
  end
end
