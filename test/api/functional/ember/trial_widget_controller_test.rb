require_relative '../../test_helper'
require 'webmock/minitest'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'trial_widget_test_helper.rb')

class Ember::TrialWidgetControllerTest < ActionController::TestCase
  include AccountTestHelper
  include CoreUsersTestHelper
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
    # new onboarding.
    get :index, controller_params({ version: 'private' }, false)
    assert_response 200
    match_json(new_trial_widget_index_pattern)
  end

  def test_index_with_forums_enabled
    Account.any_instance.stubs(:forums_eligible?).returns(true)
    Account.any_instance.stubs(:forums_setup?).returns(false)
    get :index, controller_params({ version: 'private' }, false)
    assert_response 200
    assert_equal parse_response(response.body)['tasks'].include?('name' => 'forums', 'isComplete' => false), true
    match_json(new_trial_widget_index_pattern)
    Account.any_instance.unstub(:forums_setup?)
    Account.any_instance.unstub(:forums_eligible?)
  end

  def test_index_with_email_notification_enabled
    Account.any_instance.stubs(:email_notification_eligible?).returns(true)
    Account.any_instance.stubs(:email_notification_setup?).returns(true)
    get :index, controller_params({ version: 'private' }, false)
    assert_response 200
    assert_equal parse_response(response.body)['tasks'].include?('name' => 'email_notification', 'isComplete' => true), true
    match_json(new_trial_widget_index_pattern)
    Account.any_instance.unstub(:email_notification_setup?)
    Account.any_instance.unstub(:email_notification_eligible?)
  end

  def test_index_with_onboarding_v2_tasks_complete
    setup_keys = @account.setup_keys
    setup_keys.map { |setup_key| Account.any_instance.stubs("#{setup_key}_setup?".to_sym).returns(true) }
    Account.any_instance.stubs(:support_channel_setup?).returns(true)
    get :index, controller_params({ version: 'private' }, false)
    response_tasks = parse_response(response.body)['tasks']
    assert_response 200
    assert_equal response_tasks.include?('name' => 'support_channel', 'isComplete' => true), true
    assert_equal response_tasks.include?('name' => 'manage_conversation_video', 'isComplete' => true), true
    assert_equal response_tasks.include?('name' => 'ticket_list_tour', 'isComplete' => true), true
    assert_equal response_tasks.include?('name' => 'explore_conversation_features', 'isComplete' => true), true
    assert_equal response_tasks.include?('name' => 'agent_productivity_video', 'isComplete' => true), true
    assert_equal response_tasks.include?('name' => 'canned_response_tour', 'isComplete' => true), true
    assert_equal response_tasks.include?('name' => 'explore_productivity_features', 'isComplete' => true), true
    assert_equal response_tasks.include?('name' => 'analytics_video', 'isComplete' => true), true
    assert_equal response_tasks.include?('name' => 'analytics_tour', 'isComplete' => true), true
    assert_equal response_tasks.include?('name' => 'explore_performance_feature', 'isComplete' => true), true
    assert_equal response_tasks.include?('name' => 'app_video', 'isComplete' => true), true
    assert_equal response_tasks.include?('name' => 'app_integration', 'isComplete' => true), true
    assert_equal response_tasks.include?('name' => 'explore_extend_capability_features', 'isComplete' => true), true
    match_json(new_trial_widget_index_pattern)
  ensure
    setup_keys.map { |setup_key| Account.any_instance.unstub("#{setup_key}_setup?".to_sym) }
  end

  def test_sales_manager
    WebMock.allow_net_connect!
    get :sales_manager, controller_params({ version: 'private' }, false)
    assert_response 200
    match_json(trial_widget_sales_manager_pattern)
    WebMock.disable_net_connect!
  end

  def test_complete_step_with_wrong_step_name
    step = Faker::Name.name.downcase
    post :complete_step, construct_params(steps: [step], version: 'private')
    assert_response 400
  end

  def test_complete_step_with_correct_step_name
    count = 0
    n_steps = Account::SETUP_KEYS.count
    step = Account::SETUP_KEYS[Random.rand(n_steps)]
    post :complete_step, construct_params(steps: [step], version: 'private')
    assert_response 204
  end

  def test_complete_support_channel_step_completes_admin_onboarding
    post :complete_step, construct_params(steps: ['support_channel'], version: 'private')
    assert_response 204
    refute Account.current.account_onboarding_pending?
  end

  def test_event_names_to_freshmarketer
    step_name = 'fdesk_tickets_view'
    trial_day = ((Time.now.to_i - @account.subscription.created_at.to_i) / 86400).to_i
    req_stub = stub_request(:post, "#{ThirdCrm::FRESHMARKETER_CONFIG['events_url']}?email=#{@account.admin_email}&event_name=#{ThirdCRM::FRESHMARKETER_EVENTS[:fdesk_event]}")
      .with(
        body: "{\"custom_field\":{},\"Fdesk Tickets View\":\"true\",\"Trial Day\":\"#{trial_day}\"}",
        headers: { 'Accept' => '*/*; q=0.5, application/xml', 'Accept-Encoding' => 'gzip, deflate', 'Content-Length' => '63', 'Content-Type' => 'application/json', 'Fm-Token' => 'i141ie6mbs865gne8g9h66u0ocr6v5mi0g9o3gla', 'User-Agent' => 'Ruby' }).to_return(status: 200, body: "", headers: {})
    Sidekiq::Testing.inline! do
      post :complete_step, construct_params(steps: ['fdesk_tickets_view'], version: 'private')
    end
    assert_response 204
  ensure
    @account.try("unmark_#{step_name}_setup_and_save")
    remove_request_stub(req_stub)
  end

  def test_complete_step_onboarding_goals_to_freshmarketer
    req_stub = stub_request(:post, "#{ThirdCrm::FRESHMARKETER_CONFIG['events_url']}?email=#{@account.admin_email}&event_name=#{ThirdCRM::FRESHMARKETER_EVENTS[:goal_completed]}").with(
        body: "{\"custom_field\":{}, \"goal-name\":\"fdeskgoalticket\"}",
        headers: { 'Accept' => '*/*; q=0.5, application/xml', 'Accept-Encoding' => 'gzip, deflate', 'Content-Length' => '49', 'Content-Type' => 'application/json', 'Fm-Token' => 'i141ie6mbs865gne8g9h66u0ocr6v5mi0g9o3gla', 'User-Agent' => 'Ruby' }).to_return(status: 200, body: '', headers: {})
    Sidekiq::Testing.inline! do
      post :complete_step, construct_params(steps: ['tickets_intro', 'organiseand_keep_track'], version: 'private')
    end
    assert_response 204
  ensure
    remove_request_stub(req_stub)
  end

  def test_onboarding_goals_payload_to_freshmarketer
    current_user = @account.users.current
    req_stub = stub_request(:put, ThirdCrm::FRESHMARKETER_CONFIG['contact_url'])
      .with(
        body: "{\"custom_field\":{\"cf_fdeskgoalautomation\":\"true\"},\"email\":\"#{current_user.email}\",\"last_name\":\"#{current_user.name}\"}",
        headers: {
          'Accept' => '*/*; q=0.5, application/xml',
          'Accept-Encoding' => 'gzip, deflate',
          'Content-Length' => '103',
          'Content-Type' => 'application/json',
          'Fm-Token' => 'i141ie6mbs865gne8g9h66u0ocr6v5mi0g9o3gla',
          'User-Agent' => 'Ruby'
        }
      ).to_return(status: 200, body: '', headers: {})
    Sidekiq::Testing.inline! do
      post :complete_step, construct_params(goals: ['automate_repetitive_tasks'], version: 'private')
    end
    assert_response 204
  ensure
    remove_request_stub(req_stub)
  end
end
