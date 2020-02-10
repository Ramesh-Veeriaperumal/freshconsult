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

  def test_feedback_widget_create_with_wrong_ticket_type
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    post :create, version: :private, helpdesk_ticket: { email: user.email, ticket_type: nil }
    assert_response 200
    error_response = JSON.parse(response.body)
    assert_equal error_response['success'], false
    assert_equal error_response['error'], 'Invalid ticket type'
  ensure
    log_out
    user.destroy
  end
end
