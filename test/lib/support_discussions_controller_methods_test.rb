require_relative '../api/unit_test_helper'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('spec', 'support', 'forum_helper.rb')
require Rails.root.join('spec', 'support', 'solutions_helper.rb')

class SupportDiscussionsMethodsController < ApplicationController
  include SupportDiscussionsControllerMethods
  include ActionController::Renderers::All

  def check_toggle_monitor
    toggle_monitor
    head 200
  end

  def resource_not_found_for_post
    resource_not_found(:post)
    head 200
  end

  def resource_not_found_for_topic
    resource_not_found(:topic)
    head 200
  end
end

class SupportDiscussionsMethodsControllerTest < ActionController::TestCase
  include ForumHelper
  include SolutionsHelper
  include UsersHelper

  def setup
    @account = Account.first
    Account.stubs(:current).returns(@account)
    @user = @account.users.first
    @portal = @account.portals.first || create_portal
    forum_category = @account.forum_categories.first || create_test_category
    forum = @account.forums.first || create_test_forum(forum_category)
    topic = @account.topics.first || create_test_topic(forum, @user)
    @monitorship = monitor_topic(topic, @user) if @account.monitorships.find_by_user_id(@user.id).nil?
    SupportDiscussionsMethodsController.any_instance.stubs(:monitorships).returns(@account.monitorships)
  end

  def teardown
    Account.unstub(:current)
    SupportDiscussionsMethodsController.any_instance.unstub(:monitorships)
    super
  end

  def test_toggle_monitor_with_new_monitorship_record
    @controller.instance_variable_set('@support_discussions_method', SupportDiscussionsMethodsController.new)
    response = ActionDispatch::TestResponse.new
    Monitorship.any_instance.stubs(:user_has_email).returns(true)
    @controller.response = response
    @controller.stubs(:action_name).returns('check_toggle_monitor')
    @controller.stubs(:current_user).returns(User.new)
    @controller.stubs(:current_portal).returns(@portal)
    actual = @controller.send(:check_toggle_monitor)
    assert_response 200
  ensure
    @controller.unstub(:current_user)
    Monitorship.any_instance.unstub(:user_has_email)
  end

  def test_toggle_monitor_with_existing_record
    @controller.instance_variable_set('@support_discussions_method', SupportDiscussionsMethodsController.new)
    response = ActionDispatch::TestResponse.new
    Monitorship.any_instance.stubs(:new_record?).returns(false)
    Monitorship.any_instance.stubs(:update_attributes).returns(true)
    @controller.response = response
    @controller.stubs(:action_name).returns('check_toggle_monitor')
    @controller.stubs(:current_user).returns(@user)
    @controller.stubs(:current_portal).returns(@portal)
    actual = @controller.send(:check_toggle_monitor)
    assert_response 200
  ensure
    @controller.unstub(:current_user)
    Monitorship.any_instance.unstub(:new_record?)
    Monitorship.any_instance.unstub(:update_attributes)
  end

  def test_resource_not_found_for_post_request_not_xhr
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('resource_not_found_for_post')
    assert_raises ActiveRecord::RecordNotFound do
      @controller.send(:resource_not_found_for_post)
    end
  end

  def test_resource_not_found_for_topic_not_xhr
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('resource_not_found_for_topic')
    @controller.send(:resource_not_found_for_topic)
    assert_response 200
  end

  def test_resource_not_found_for_xhr_html_format
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('resource_not_found_for_post')
    @request.env['X-PJAX'] = '1'
    @request.env['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest'
    @controller.send(:resource_not_found_for_post)
    assert_response 200
  end

  def test_resource_not_found_for_xhr_js_format
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.stubs(:action_name).returns('resource_not_found_for_topic')
    @request.env['HTTP_ACCEPT'] = 'text/javascript'
    @request.env['HTTP_X_REQUESTED_WITH'] = 'XMLHttpRequest'
    @controller.send(:resource_not_found_for_topic)
    assert_response 200
  end
end
