require_relative '../../test_helper.rb'

class Admin::SecurityKeysControllerTest < ActionController::TestCase
  def setup
    super
    Account.current.add_feature(:help_widget)
  end

  def teardown
    super
    Account.current.remove_feature(:help_widget)
  end

  def test_regenerate_widget_key
    old_secret = Account.current.help_widget_secret
    put :regenerate_widget_key, construct_params(version: 'private')
    assert_response 200
    assert_not_equal old_secret, Account.current.help_widget_secret
  end

  def test_regenerate_widget_key_without_privilage
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    old_secret = Account.current.help_widget_secret
    put :regenerate_widget_key, construct_params(version: 'private')
    assert_response 403
    assert_equal old_secret, Account.current.help_widget_secret
  end

  def test_regenerate_widget_key_without_help_widget
    Account.current.stubs(:help_widget_enabled?).returns(false)
    old_secret = Account.current.help_widget_secret
    put :regenerate_widget_key, construct_params(version: 'private')
    assert_response 403
    assert_equal old_secret, Account.current.help_widget_secret
    Account.current.unstub(:help_widget_enabled?)
  end
end
