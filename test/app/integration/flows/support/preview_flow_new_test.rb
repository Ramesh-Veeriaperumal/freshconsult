# frozen_string_literal: true

require_relative '../../../../../test/api/api_test_helper'
require Rails.root.join('test', 'api', 'helpers', 'privileges_helper.rb')

class Support::PreviewFlowTest < ActionDispatch::IntegrationTest
  include Redis::RedisKeys
  include Redis::PortalRedis
  include PrivilegesHelper

  def test_should_render_preview_portal
    preview_url = "http://#{@account.full_domain}/support/home"
    account_wrap do
      get 'support/preview'
    end
    assert_response 200
    assert_template 'support/preview/index'
    assert_tag :iframe, attributes: { src: preview_url }
    assert_equal preview_url, assigns[:preview_url]
  end

  def test_should_render_preview_portal_with_mint_preview
    mint_preview_key = format(MINT_PREVIEW_KEY, account_id: @account.id, user_id: @agent.id, portal_id: @account.portals.first.id)
    mint_preview = true
    preview_url = "http://#{@account.full_domain}/support/home?mint_preview=#{mint_preview}"
    account_wrap do
      get "support/preview?mint_preview=#{mint_preview}"
    end
    assert_response 200
    assert_template 'support/preview/index'
    assert_tag :iframe, attributes: { src: preview_url }
    assert_equal preview_url, assigns[:preview_url]
    assert_equal 'true', get_others_redis_key(mint_preview_key)
    assert_equal 300, get_others_redis_expiry(mint_preview_key)
  end

  def test_should_render_preview_portal_with_mint_preview_toggle
    mint_preview_key = format(MINT_PREVIEW_KEY, account_id: @account.id, user_id: @agent.id, portal_id: @account.portals.first.id)
    old_preview_key = format(IS_PREVIEW, account_id: @account.id, user_id: User.first.id, portal_id: @account.portals.first.id)
    mint_preview_toggle = true
    preview_url = "http://#{@account.full_domain}/support/home?mint_preview=true"
    account_wrap do
      get "support/preview?mint_preview_toggle=#{mint_preview_toggle}"
    end
    assert_response 200
    assert_template 'support/preview/index'
    assert_tag :iframe, attributes: { src: preview_url }
    assert_equal preview_url, assigns[:preview_url]
    assert_equal 'true', get_others_redis_key(mint_preview_key)
    assert_equal 300, get_others_redis_expiry(mint_preview_key)
    assert_nil get_portal_redis_key(old_preview_key)
  end

  def test_should_render_preview_portal_with_mint_preview_toggle_and_classic_view_enabled
    old_preview_key = format(IS_PREVIEW, account_id: @account.id, user_id: User.first.id, portal_id: @account.portals.first.id)
    mint_preview_key = format(MINT_PREVIEW_KEY, account_id: @account.id, user_id: @agent.id, portal_id: @account.portals.first.id)
    mint_preview_toggle = true
    classic = true
    preview_url = "http://#{@account.full_domain}/support/home"
    account_wrap do
      get "support/preview?mint_preview_toggle=#{mint_preview_toggle}&classic=#{classic}"
    end
    assert_response 200
    assert_template 'support/preview/index'
    assert_tag :iframe, attributes: { src: preview_url }
    assert_equal preview_url, assigns[:preview_url]
    assert_equal 'true', get_portal_redis_key(old_preview_key)
    assert_nil get_others_redis_key(mint_preview_key)
  end

  def test_should_render_preview_portal_with_given_preview_url
    preview_url_key = format(PREVIEW_URL, account_id: @account.id, user_id: User.first.id, portal_id: @account.portals.first.id)
    preview_url = "http://#{@account.full_domain}/support/solutions"
    set_portal_redis_key(preview_url_key, preview_url)
    account_wrap do
      get 'support/preview'
    end
    assert_response 200
    assert_template 'support/preview/index'
    assert_tag :iframe, attributes: { src: preview_url }
    assert_equal preview_url, assigns[:preview_url]
    assert_equal preview_url, get_portal_redis_key(preview_url_key)
  end

  def test_should_render_preview_portal_with_given_preview_url_with_mint_preview
    preview_url_key = format(PREVIEW_URL, account_id: @account.id, user_id: User.first.id, portal_id: @account.portals.first.id)
    preview_url = "http://#{@account.full_domain}/support/solutions"
    mint_preview_key = format(MINT_PREVIEW_KEY, account_id: @account.id, user_id: @agent.id, portal_id: @account.portals.first.id)
    mint_preview = true
    set_portal_redis_key(preview_url_key, preview_url)
    account_wrap do
      get "support/preview?mint_preview=#{mint_preview}"
    end
    assert_response 200
    assert_template 'support/preview/index'
    assert_equal preview_url, get_portal_redis_key(preview_url_key)
    assert_equal "#{preview_url}?mint_preview = '#{mint_preview}'", assigns[:preview_url]
    assert_equal 'true', get_others_redis_key(mint_preview_key)
    assert_equal 300, get_others_redis_expiry(mint_preview_key)
  end

  def test_should_render_preview_portal_with_given_preview_url_with_mint_preview_toggle
    preview_url_key = format(PREVIEW_URL, account_id: @account.id, user_id: User.first.id, portal_id: @account.portals.first.id)
    mint_preview_key = format(MINT_PREVIEW_KEY, account_id: @account.id, user_id: @agent.id, portal_id: @account.portals.first.id)
    preview_url = "http://#{@account.full_domain}/support/solutions"
    mint_preview_toggle = true
    mint_preview = true
    set_portal_redis_key(preview_url_key, preview_url)
    account_wrap do
      get "support/preview?mint_preview_toggle=#{mint_preview_toggle}"
    end
    assert_response 200
    assert_template 'support/preview/index'
    assert_equal preview_url, get_portal_redis_key(preview_url_key)
    assert_equal "#{preview_url}?mint_preview = '#{mint_preview}'", assigns[:preview_url]
    assert_equal 'true', get_others_redis_key(mint_preview_key)
    assert_equal 300, get_others_redis_expiry(mint_preview_key)
  end

  def test_index_with_preview_url_when_mint_preview_toggle_and_classic_view_is_on
    old_preview_key = format(IS_PREVIEW, account_id: @account.id, user_id: User.first.id, portal_id: @account.portals.first.id)
    mint_preview_key = format(MINT_PREVIEW_KEY, account_id: @account.id, user_id: @agent.id, portal_id: @account.portals.first.id)
    preview_url_key = format(PREVIEW_URL, account_id: @account.id, user_id: User.first.id, portal_id: @account.portals.first.id)
    preview_url = "http://#{@account.full_domain}/support/solutions"
    mint_preview_toggle = true
    classic = true
    set_portal_redis_key(preview_url_key, preview_url)
    account_wrap do
      get "support/preview?mint_preview_toggle=#{mint_preview_toggle}&classic=#{classic}"
    end
    assert_response 200
    assert_template 'support/preview/index'
    assert_tag :iframe, attributes: { src: preview_url }
    assert_equal preview_url, assigns[:preview_url]
    assert_equal 'true', get_portal_redis_key(old_preview_key)
    assert_nil get_others_redis_key(mint_preview_key)
  end

  def test_preview_portal_with_suspended_account
    old_subscription_state = @account.subscription.state
    @account.subscription.state = 'suspended'
    @account.subscription.updated_at = 2.days.ago
    @account.subscription.save
    preview_url = "http://#{@account.full_domain}/support/home"
    account_wrap do
      get 'support/preview'
    end
    assert_response 302
    assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  ensure
    @account.subscription.state = old_subscription_state
    @account.subscription.save
  end

  def test_should_redirect_to_login_page_without_login_feature
    preview_url = "http://#{@account.full_domain}/support/home"
    user = add_new_user(@account, active: true)
    reset_request_headers
    account_wrap(user) do
      get 'support/preview'
    end
    assert_response 302
    assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  end

  def test_should_redirect_to_request_path_without_multilingual_and_with_url_local
    preview_url = "http://#{@account.full_domain}/support/home"
    account_wrap do
      get "#{@account.language}/support/preview"
    end
    assert_response 302
    assert_redirected_to '/support/preview'
  end

  def test_should_redirect_to_request_path_with_multilingual_and_without_url_local
    @account.add_feature(:multi_language)
    Account.any_instance.stubs(:multilingual?).returns(true)
    preview_url = "http://#{@account.full_domain}/support/home"
    account_wrap do
      get '/support/preview'
    end
    assert_response 302
    assert_redirected_to "/#{@account.language}/support/preview"
  ensure
    @account.remove_feature(:multi_language)
    Account.any_instance.unstub(:multilingual?)
  end

  def test_should_render_preview_portal_multilingual_and_with_url_local
    @account.add_feature(:multi_language)
    Account.any_instance.stubs(:multilingual?).returns(true)
    preview_url = "http://#{@account.full_domain}/#{@account.language}/support/home"
    account_wrap do
      get "#{@account.language}/support/preview"
    end
    assert_response 200
    assert_tag :iframe, attributes: { src: preview_url }
    assert_equal preview_url, assigns[:preview_url]
  ensure
    @account.remove_feature(:multi_language)
    Account.any_instance.unstub(:multilingual?)
  end

  def test_preview_route_with_deny_inframe_is_set
    AccountAdditionalSettings.any_instance.stubs(:security).returns(deny_iframe_embedding: true)
    account_wrap do
      get 'support/preview'
    end
    assert_response 200
    assert_template 'support/preview/index'
    assert_equal response.headers['X-Frame-Options'], 'SAMEORIGIN'
  ensure
    AccountAdditionalSettings.any_instance.unstub(:security)
  end

  def test_preview_portal_for_agent_without_admin_tasks_privilege
    agent = add_test_agent(@account, role: Role.find_by_name('Agent').id)
    set_request_auth_headers(agent)
    remove_privilege(agent, :admin_tasks) if agent.privilege?(:admin_tasks)
    preview_url = "http://#{@account.full_domain}/support/home"
    account_wrap(agent) do
      get 'support/preview'
    end
    assert_response 302
    assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  ensure
    add_privilege(agent, :admin_tasks)
    agent.destroy
  end

  def test_preview_portal_as_customer
    company = create_company
    user = add_new_user(@account, active: true, customer_id: company.id)
    set_request_auth_headers(user)
    preview_url = "http://#{@account.full_domain}/support/home"
    account_wrap(user) do
      get 'support/preview'
    end
    assert_response 302
    assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  end

  private

    def create_company
      company = Company.create(name: Faker::Name.name, account_id: @account.id)
      company.save
      company
    end

    def old_ui?
      true
    end
end
