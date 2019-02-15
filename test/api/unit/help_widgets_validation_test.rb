require_relative '../unit_test_helper'

class HelpWidgetsValidationTest < ActionView::TestCase

  def test_create_invalid_without_settings
    Account.stubs(:current).returns(Account.new)
    request_params  = {
      'product_id' => 1,
      'name' => 'Create_Widget'
    }
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:create)
    errors=helpwidgetsvalidation.errors.full_messages
    assert errors.include?("Settings can't be blank")
  end

  def test_create_invalid_with_false_settings_hash
    Account.stubs(:current).returns(Account.new)
    request_params = {
      product_id: 5,
      name: 'Ram',
      settings: {
        length: '900px'
      }
    }
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:create)
    errors=helpwidgetsvalidation.errors.full_messages
    p errors
    assert errors.include?("Length Invalid settings hash with length")
  end

  def test_create_invalid_with_false_settings_type
    Account.stubs(:current).returns(Account.new)
    request_params = {
      product_id: 5,
      name: "Harry",
      settings: true
    }
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:create)
    errors=helpwidgetsvalidation.errors.full_messages
    p errors
    assert errors.include?("Settings datatype_mismatch")
  end

  def test_create_valid_with_expected_parameters
    Account.stubs(:current).returns(Account.new)
    request_params = {
      product_id: nil,
      name: "Harry",
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
    Account.stubs(:current).returns(Account.new)
    request_params ={
      id: 1,
      settings: {
        appearance: {
          sdsd: 1
        }
      }
    }
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:update)
    errors=helpwidgetsvalidation.errors.full_messages
    p errors
    assert errors.include?("Sdsd Invalid settings hash with sdsd")
  end

  def test_update_invalid_with_invalid_contact_form_hash
    Account.stubs(:current).returns(Account.new)
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
    errors=helpwidgetsvalidation.errors.full_messages
    p errors
    errors.include?("Sdsd Invalid settings hash with contact_form : sdsd")
  end

  def test_update_valid_with_valid_hashes
    Account.stubs(:current).returns(Account.new)
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

  def test_update_valid_with_solution_articles
    Account.stubs(:current).returns(Account.new)
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
    Account.stubs(:current).returns(Account.new)
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
    Account.stubs(:current).returns(Account.new)
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
    Account.stubs(:current).returns(Account.new)
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
    errors=helpwidgetsvalidation.errors.full_messages
    assert errors.include?("Settings invalid_format")
  end

  def test_update_valid_with_valid_appearance_settings
    Account.stubs(:current).returns(Account.new)
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
    errors=helpwidgetsvalidation.errors.full_messages
    assert errors.blank?
  end

    def test_update_valid_with_invalid_appearance_settings
    Account.stubs(:current).returns(Account.new)
    request_params = ActionController::Parameters.new ({
      'id' => 1,
      'settings' => {
        'appearance' => {
          'color_schema' => 110,
          'gradient' => 29,
          'pattern' => 4
        }
      }
    })
    helpwidgetsvalidation = HelpWidgetValidation.new(request_params)
    refute helpwidgetsvalidation.valid?(:update)
  end
end
