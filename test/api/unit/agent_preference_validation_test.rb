require_relative '../../test_helper'

class AgentPreferencesValidationTest < ActionView::TestCase
  def test_shortcuts_enabled_param_value_is_not_boolean
    controller_params = { shortcuts_enabled: 'true' }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    refute agent.valid?
    errors = agent.errors.full_messages
    assert errors.include?('Shortcuts enabled datatype_mismatch'), errors[0]
    assert_equal({ shortcuts_enabled: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String } }, agent.error_options)
  end

  def test_shortcuts_mapping_param_value_is_not_array_of_hashes
    controller_params = { shortcuts_mapping: ['true'] }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    refute agent.valid?
    errors = agent.errors.full_messages
    assert errors.include?('Shortcuts mapping array_datatype_mismatch'), errors[0]
    assert_equal({ shortcuts_mapping: { expected_data_type: 'key/value pair' } }, agent.error_options)
  end

  def test_notification_timestamp_param_value_is_not_string
    controller_params = { notification_timestamp: true }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    refute agent.valid?
    errors = agent.errors.full_messages
    assert errors.include?('Notification timestamp invalid_date'), errors[0]
    assert_equal({ notification_timestamp: { accepted: :'combined date and time ISO8601' } }, agent.error_options)
  end

  def test_show_onboarding_param_value_is_not_boolean
    controller_params = { show_onBoarding: 'true' }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    refute agent.valid?
    errors = agent.errors.full_messages
    assert errors.include?('Show onboarding datatype_mismatch'), errors[0]
    assert_equal({ show_onBoarding: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String } }, agent.error_options)
  end

  def test_falcon_ui_param_value_is_not_boolean
    controller_params = { falcon_ui: 'true' }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    refute agent.valid?
    errors = agent.errors.full_messages
    assert errors.include?('Falcon ui datatype_mismatch'), errors[0]
    assert_equal({ falcon_ui: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String } }, agent.error_options)
  end

  def test_undo_send_param_value_is_not_boolean
    controller_params = { undo_send: 'true' }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    refute agent.valid?
    errors = agent.errors.full_messages
    assert errors.include?('Undo send datatype_mismatch'), errors[0]
    assert_equal({ undo_send: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String } }, agent.error_options)
  end

  def test_focus_mode_param_value_is_not_boolean
    controller_params = { focus_mode: 'true' }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    refute agent.valid?
    errors = agent.errors.full_messages
    assert errors.include?('Focus mode datatype_mismatch'), errors[0]
    assert_equal({ focus_mode: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String } }, agent.error_options)
  end

  def test_field_service_param_value_is_not_hash_of_hashes
    controller_params = { field_service: { dismissed_sample_scheduling_dashboard: 'true' } }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    refute agent.valid?
    errors = agent.errors.full_messages
    assert errors.include?('Field service datatype_mismatch'), errors[0]
    assert_equal({ field_service: { expected_data_type: 'Boolean', nested_field: :dismissed_sample_scheduling_dashboard } }, agent.error_options)
  end

  def test_search_settings_param_value_is_not_hash_of_hash_of_hashes
    controller_params = { search_settings: { tickets: { include_subject: 'test' } } }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    refute agent.valid?
    errors = agent.errors.full_messages
    assert errors.include?('Search settings datatype_mismatch'), errors[0]
    assert_equal({ search_settings: { expected_data_type: 'Boolean', nested_field: :include_subject } }, agent.error_options)
  end

  # Possitive test cases
  def test_shortcuts_enabled_param_value_is_boolean
    controller_params = { shortcuts_enabled: true }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    assert agent.valid?
  end

  def test_shortcuts_mapping_param_value_is_array_of_hashes
    controller_params = { shortcuts_mapping: [{ create_ticket: 'T' }] }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    assert agent.valid?
  end

  def test_notification_timestamp_param_value_is_string
    controller_params = { notification_timestamp: '2020-01-14T13:19:17.903Z' }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    assert agent.valid?
  end

  def test_show_onboarding_param_value_is_boolean
    controller_params = { show_onBoarding: true }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    assert agent.valid?
  end

  def test_falcon_ui_param_value_is_boolean
    controller_params = { falcon_ui: true }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    assert agent.valid?
  end

  def test_undo_send_param_value_is_boolean
    controller_params = { undo_send: true }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    assert agent.valid?
  end

  def test_focus_mode_param_value_is_boolean
    controller_params = { focus_mode: true }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    assert agent.valid?
  end

  def test_field_service_param_value_is_hash_of_hashes
    controller_params = { field_service: { dismissed_sample_scheduling_dashboard: true } }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    assert agent.valid?
  end

  def test_search_settings_param_value_is_hash_of_hash_hashes
    controller_params = { search_settings: { tickets: { include_subject: true } } }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    assert agent.valid?
  end

  def test_show_loyalty_upgrade_param_value_is_not_boolean
    controller_params = { show_loyalty_upgrade: 'true' }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    refute agent.valid?
    errors = agent.errors.full_messages
    assert errors.include?('Show loyalty upgrade datatype_mismatch'), errors[0]
    assert_equal({ show_loyalty_upgrade: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String } }, agent.error_options)
  end

  def test_show_loyalty_upgrade_param_value_is_boolean
    controller_params = { show_loyalty_upgrade: true }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    assert agent.valid?
  end

  def test_show_monthly_to_annual_notification_param_value_is_not_boolean
    controller_params = { show_monthly_to_annual_notification: 'true' }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    refute agent.valid?
    errors = agent.errors.full_messages
    assert errors.include?('Show monthly to annual notification datatype_mismatch'), errors[0]
    assert_equal({ show_monthly_to_annual_notification: { expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String } }, agent.error_options)
  end

  def test_show_monthly_to_annual_notification_param_value_is_boolean
    controller_params = { show_monthly_to_annual_notification: true }
    agent = Ember::AgentPreferencesValidation.new(controller_params, nil)
    assert agent.valid?
  end
end
