require_relative '../unit_test_helper'

class HelpWidgetsValidationTest < ActionView::TestCase
  def setup
    super
    before_all
  end

  def before_all
    @account = Account.stubs(:current).returns(Account.new)
  end

  def request_params_setting(id: 1, level_one: 'settings', level_two: 'components', value: {})
    ActionController::Parameters.new ({
      'id' => id,
      level_one => {
        level_two => value
      }
    })
  end

  def test_create_invalid_without_settings
    request_params = {
      'product_id' => 1,
      'name' => 'Create_Widget'
    }
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:create)
    errors = helpwidgetsvalidation.errors.full_messages
    assert errors.include?('Settings can\'t be blank')
  end

  def test_create_invalid_with_false_settings_hash
    request_params = {
      product_id: 5,
      name: 'Ram',
      settings: {
        length: '900px'
      }
    }
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:create)
    errors = helpwidgetsvalidation.errors.full_messages
    assert errors.include?('Length Invalid settings hash with length')
  end

  def test_create_invalid_with_false_settings_type
    request_params = {
      product_id: 5,
      name: 'Harry',
      settings: true
    }
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:create)
    errors = helpwidgetsvalidation.errors.full_messages
    assert errors.include?('Settings datatype_mismatch')
  end

  def test_create_valid_with_expected_parameters
    request_params = {
      product_id: nil,
      name: 'Harry',
      settings: {
        components: {
          contact_form: true
        }
      }
    }
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    assert helpwidgetsvalidation.valid?(:create)
  end

  def test_update_invalid_with_invalid_appearance_hash
    request_params = {
      id: 1,
      settings: {
        appearance: {
          sdsd: 1
        }
      }
    }
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:update)
    errors = helpwidgetsvalidation.errors.full_messages
    assert errors.include?('Sdsd Invalid settings hash with sdsd')
  end

  def test_update_invalid_with_invalid_contact_form_hash
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'contact_form' => {
          'sdsd' => 1
        }
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:update)
    errors = helpwidgetsvalidation.errors.full_messages
    errors.include?('Sdsd Invalid settings hash with contact_form : sdsd')
  end

  def test_update_with_require_login
    request_hash = { 'require_login' => true }
    request_params = request_params_setting(level_two: 'contact_form', value: request_hash)
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    assert helpwidgetsvalidation.valid?(:update)
  end

  def test_update_invalid_with_invalid_require_login
    request_hash = { 'require_login' => 'ssdsd' }
    request_params = request_params_setting(level_two: 'contact_form', value: request_hash)
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:update)
    errors = helpwidgetsvalidation.errors.full_messages
    assert errors.include?('Settings datatype_mismatch')
  end

  def test_update_valid_with_valid_hashes
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'appearance' => {
          'position' => 1
        }
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    assert helpwidgetsvalidation.valid?(:update)
  end

  def test_update_valid_with_valid_button_text
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'button_text' => 'Help'
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    assert helpwidgetsvalidation.valid?(:update)
  end

  def test_update_valid_with_invalid_button_text
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'button_text' => 'Help me . Click me. I\'ll pop up'
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:update)
  end

  def test_update_valid_with_empty_button_text
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'button_text' => nil
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:update)
  end

  def test_update_valid_with_solution_articles
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'components' => {
          'solution_articles' => true
        }
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    assert helpwidgetsvalidation.valid?(:update)
  end

  def test_update_valid_with_solution_articles_widget_flow
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'widget_flow' => 1
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    assert helpwidgetsvalidation.valid?(:update)
  end

  def test_update_valid_with_solution_articles_widget_flow_invalid
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'widget_flow' => 13
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:update)
  end

  def test_update_invalid_with_invalid_color_code
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'appearance' => {
          'theme_color' => '1c3c1c'
        }
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:update)
    errors = helpwidgetsvalidation.errors.full_messages
    assert errors.include?('Settings invalid_format')
  end

  def test_update_components_with_predictive_support
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'components' => {
          'predictive_support' => true
        }
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    assert helpwidgetsvalidation.valid?(:update)
  end

  def test_update_valid_with_valid_appearance_settings
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'appearance' => {
          'color_schema' => 1,
          'gradient' => 2,
          'pattern' => 4
        }
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    assert helpwidgetsvalidation.valid?(:update)
  end

  def test_update_valid_predictive_support_hash
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'predictive_support' => {
          'domain_list' => ['us.ikl.ok'],
          'welcome_message' => 'hi',
          'success_message' => 'Succcess',
          'message' => 'hello'
        }
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    errors = helpwidgetsvalidation.errors.full_messages
    assert errors.blank?
  end

  def test_update_invalid_predictive_support_hash
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'predictive_support' => {
          'welcome' => 'hi',
          'success' => 'Succcess',
          'message' => 'hello'
        }
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:update)
  end

  def test_update_predictive_support_with_fm_account_creation
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'components' => {
          'predictive_support' => true
        },
        'predictive_support' => {
          'domain_list' => ['test.com'],
          'welcome_message' => 'hi',
          'success_message' => 'Succcess',
          'message' => 'hello'
        }
      },
      'freshmarketer' => {
        email: 'padmashri@fmstack.com',
        type: 'create'
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    assert helpwidgetsvalidation.valid?(:update)
  end

  def test_update_predictive_support_with_fm_account_association
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'components' => {
          'predictive_support' => true
        },
        'predictive_support' => {
          'domain_list' => ['test.com'],
          'welcome_message' => 'hi',
          'success_message' => 'Succcess',
          'message' => 'hello'
        }
      },
      'freshmarketer' => {
        domain: 'padmashri.fmstack.com',
        type: 'associate'
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    assert helpwidgetsvalidation.valid?(:update)
  end

  def test_update__with_fm_account_creation_wrong_type
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'components' => {
          'predictive_support' => true
        },
        'predictive_support' => {
          'domain_list' => ['test.com'],
          'welcome_message' => 'hi',
          'success_message' => 'Succcess',
          'message' => 'hello'
        }
      },
      'freshmarketer' => {
        domain: 'padmashri@fmstack.com',
        type: 'serve'
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:update)
  end

  def test_update_empty_text_fields_predictive_support_hash
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'predictive_support' => {
          'domain_list' => ['ui.okl.po'],
          'welcome_message' => nil,
          'success_message' => nil,
          'message' => nil
        }
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    assert helpwidgetsvalidation.valid?(:update)
  end
end
