require_relative '../unit_test_helper'
class IntegratedUserValidationTest < ActionView::TestCase
  def test_value_valid
    installed_app = IntegratedUserValidation.new({ action: 'index', installed_application_id: 1, user_id: 1 }, nil)
    assert installed_app.valid?
  end

  def test_value_invalid_installed_app
    installed_app = IntegratedUserValidation.new({ action: 'index', installed_application_id: 'afdafds', user_id: 1 }, nil)
    refute installed_app.valid?
    errors = installed_app.errors.full_messages
    assert errors.include?('Installed application datatype_mismatch')
  end

  def test_value_invalid_user_id
    installed_app = IntegratedUserValidation.new({ action: 'index', installed_application_id: 1, user_id: 'asdfsdaf' }, nil)
    refute installed_app.valid?
    errors = installed_app.errors.full_messages
    assert errors.include?('User datatype_mismatch')
  end

  def test_value_with_nil
    installed_app = IntegratedUserValidation.new({ action: 'index', installed_application_id: nil, user_id: 1 }, nil)
    refute installed_app.valid?
    errors = installed_app.errors.full_messages
    assert errors.include?('Installed application installed_application_id_required')
  end

  def test_value_username
    installed_app = IntegratedUserValidation.new({ action: 'user_credentials_add', installed_application_id: 1, username: nil, password: 'erfr' }, nil)
    refute installed_app.valid?
    errors = installed_app.errors.full_messages
    assert errors.include?('Username username_required')
  end

  def test_value_password
    installed_app = IntegratedUserValidation.new({ action: 'user_credentials_add', installed_application_id: 1, username: 'ee', password: nil }, nil)
    refute installed_app.valid?
    errors = installed_app.errors.full_messages
    assert errors.include?('Password password_required')
  end
end
