require_relative '../../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'trial_widget_test_helper.rb')

class Ember::TrialWidgetControllerTest < ActionController::TestCase
  include AccountTestHelper
  include UsersTestHelper
  include TrialWidgetTestHelper

  def setup
    super
    before_all
  end

  def before_all
    @user = create_test_account
    @account = @user.account.make_current
  end

  def test_trial_widget_index
    json = get :index, controller_params({ version: 'private' }, false)
    assert_response 200
    match_json(trial_widget_index_pattern)
  end

  def test_trial_widget_sales_manager
    json = get :sales_manager, controller_params({ version: 'private' }, false)
    assert_response 200
    match_json(trial_widget_sales_manager_pattern)
  end
end
