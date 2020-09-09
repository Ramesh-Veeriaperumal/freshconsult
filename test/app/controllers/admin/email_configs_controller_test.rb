# frozen_string_literal: true

require_relative '../../../api/test_helper'
class Admin::EmailConfigsControllerTest < ActionController::TestCase
  include EmailConfigsTestHelper

  def test_redirect_for_google_signin
    email_config = create_email_config
    get :google_signin, controller_params(id: email_config.id, support_email: email_config.to_email, type: 'edit', access_type: 'outgoing')
    assert_response :redirect
    assert_includes @response.redirect_url, 'auth/gmail'
  end

  def test_redirect_for_microsoft_signin
    email_config = create_email_config
    get :microsoft_signin, controller_params(id: email_config.id, support_email: email_config.to_email, type: 'edit', access_type: 'outgoing')
    assert_response :redirect
    assert_includes @response.redirect_url, 'auth/outlook'
  end
end
