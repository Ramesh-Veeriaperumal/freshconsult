require_relative '../../../api/test_helper'
require_relative '../../../core/helpers/users_test_helper'
require_relative '../../../core/helpers/controller_test_helper'
require_relative '../../../core/helpers/tickets_test_helper'
require_relative '../../../core/helpers/users_test_helper'

class Widgets::FeedbackWidgetsControllerTest < ActionController::TestCase
  include ControllerTestHelper
  include CoreTicketsTestHelper
  include CoreUsersTestHelper

  def setup
    super
  end

  def test_feedback_widget_create_with_wrong_ticket_type
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    post :create, version: :private, helpdesk_ticket: { email: user.email, ticket_type: "Question<svg/onload=alert('XSS')>" }
    assert_response 200
    error_response = JSON.parse(response.body)
    assert_equal error_response['success'], false
    assert_equal error_response['error'], 'Invalid ticket type'
  ensure
    log_out
    user.destroy
  end

  def test_feedback_widget_create_with_correct_ticket_type
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    post :create, version: :private, helpdesk_ticket: { email: user.email, ticket_type: 'Question' }
    assert_response 200
  ensure
    log_out
    user.destroy
  end

  def test_feedback_widget_create_with_screenshot_disabled
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    post :create, version: :private, helpdesk_ticket: { email: user.email, ticket_type: 'Question' }, screenshot: Faker::Lorem.words(3)
    assert_response 200
    refute JSON.parse(response.body)['success']
  ensure
    log_out
    user.destroy
  end

  def test_feedback_widget_create_with_attachment_disabled
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    post :create, version: :private, helpdesk_ticket: { email: user.email, ticket_type: 'Question', attachments: Faker::Lorem.words(3) }
    assert_response 200
    refute JSON.parse(response.body)['success']
  ensure
    log_out
    user.destroy
  end

  def test_feedback_widget_create_with_empty_ticket_type
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    post :create, version: :private, helpdesk_ticket: { email: user.email, ticket_type: '' }
    assert_response 200
  ensure
    log_out
    user.destroy
  end

  def test_feedback_widget_create_with_nil_ticket_type
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    post :create, version: :private, helpdesk_ticket: { email: user.email, ticket_type: nil }
    assert_response 200
  ensure
    log_out
    user.destroy
  end

  def test_feedback_widget_create_with_captcha_true
    Account.any_instance.stubs(:feedback_widget_captcha_allowed?).returns(true)
    @controller.stubs(:current_user).returns(nil)
    @controller.stubs(:verify_recaptcha).returns(false)
    retain_params = { widgetType: 'popup' }.to_json
    post :create, version: :private, helpdesk_ticket: { email: 'abc@gmail.com', ticket_type: 'Question' }, widgetType: 'popup', retainParams: retain_params
    assert_response 200
    refute JSON.parse(response.body)['success']
  ensure
    Account.any_instance.unstub(:feedback_widget_captcha_allowed?)
    @controller.unstub(:current_user)
    @controller.unstub(:verify_recaptcha)
  end

  def test_feedback_widget_create_from_account_with_ehawk_spam_4_and_above
    Account.any_instance.stubs(:ehawk_spam?).returns(true)
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    post :create, version: :private, helpdesk_ticket: { email: user.email, ticket_type: 'Question' }
    assert_response 403
    error_response = JSON.parse(response.body)
    assert_equal error_response['success'], false
    assert_equal error_response['error'], 'You have been restricted from creating a ticket.'
  ensure
    Account.any_instance.unstub(:ehawk_spam?)
  end
end
