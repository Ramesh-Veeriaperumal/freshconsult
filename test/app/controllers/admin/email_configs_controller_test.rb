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

  def test_toggle_compose_email_setting
    Account.any_instance.stubs(:compose_email_enabled?).returns(false)
    post :toggle_compose_email_setting
    assert_response 200
    assert Account.current.has_feature?(:compose_email)
    Account.any_instance.stubs(:compose_email_enabled?).returns(true)
    post :toggle_compose_email_setting
    refute Account.current.has_feature?(:compose_email)
  ensure
    Account.any_instance.unstub(:compose_email_enabled?)
  end

  def test_toggle_agent_forward_setting
    Account.any_instance.stubs(:disable_agent_forward_enabled?).returns(false)
    post :toggle_agent_forward_setting
    assert_response 200
    assert Account.current.has_feature?(:disable_agent_forward)
    Account.any_instance.stubs(:disable_agent_forward_enabled?).returns(true)
    post :toggle_agent_forward_setting
    assert_response 200
    refute Account.current.has_feature?(:disable_agent_forward)
  ensure
    Account.any_instance.unstub(:compose_email_enabled?)
  end

  def test_personalized_email_enable_and_disable
    Account.current.disable_setting(:personalized_email_enable) if Account.current.personalized_email_replies_enabled?
    post :personalized_email_enable
    assert Account.current.personalized_email_replies_enabled?
    post :personalized_email_disable
    refute Account.current.personalized_email_replies_enabled?
  end

  def test_reply_to_email_disable_enable_and_disable
    Account.current.enable_setting(:reply_to_based_tickets) unless Account.current.reply_to_based_tickets_enabled?
    post :reply_to_email_disable
    refute Account.current.reply_to_based_tickets_enabled?
    post :reply_to_email_enable
    assert Account.current.reply_to_based_tickets_enabled?
  end
end
