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

  def test_index
    get :index, controller_params({ version: 'private' }, false)
    assert_response 200
    match_json(trial_widget_index_pattern)
  end

  def test_index_with_forums_enabled
    Account.any_instance.stubs(:forums_eligible?).returns(true)
    Account.any_instance.stubs(:forums_setup?).returns(false)
    get :index, controller_params({ version: 'private' }, false)
    assert_response 200
    assert_equal parse_response(response.body)["tasks"].include?({"name"=>"forums", "isComplete"=>false}), true
    match_json(trial_widget_index_pattern)
    Account.any_instance.unstub(:forums_setup?)
    Account.any_instance.unstub(:forums_eligible?)
  end

  def test_index_with_email_notification_enabled
    Account.any_instance.stubs(:email_notification_eligible?).returns(true)
    Account.any_instance.stubs(:email_notification_setup?).returns(true)
    get :index, controller_params({ version: 'private' }, false)
    assert_response 200
    assert_equal parse_response(response.body)["tasks"].include?({"name"=>"email_notification", "isComplete"=>true}), true
    match_json(trial_widget_index_pattern)
    Account.any_instance.unstub(:email_notification_setup?)
    Account.any_instance.unstub(:email_notification_eligible?)
  end

  def test_sales_manager
    get :sales_manager, controller_params({ version: 'private' }, false)
    assert_response 200
    match_json(trial_widget_sales_manager_pattern)
  end

  def test_complete_step_with_wrong_step_name
    step = Faker::Name.name.downcase
    post :complete_step, construct_params({ step: step, version: 'private' })
    assert_response 400
  end

  def test_complete_step_with_correct_step_name
    count = 0
    n_steps = Account::SETUP_KEYS.count
    step = Account::SETUP_KEYS[Random.rand(n_steps)]
    response = @account.respond_to?("#{step}_setup?") && @account.send("#{step}_setup?") ? 204 : 200
    post :complete_step, construct_params({ step: step, version: 'private' })
    assert_response response
  end
end
