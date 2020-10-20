# frozen_string_literal: true

require_relative '../../test_helper'

class ActionDispatchCookiesFlowsTest < ActionDispatch::IntegrationTest
  include Redis::RedisKeys
  include Redis::OthersRedis
  def sample_user
    @account.all_agents.first
  end

  def setup
    CustomRequestStore.store[:private_api_request] ||= true
    super
  end
  
  def test_action_dispatch_cookies_should_have_same_site_none_when_same_site_launched
    Account.current.launch(:same_site_none)
    get '/api/_/contact_fields', nil, @headers
    assert_response 200
    cookie_header = response.headers['Set-Cookie'].split("\n")
    cookie_header.each do |cookie|
      assert cookie.include?('SameSite=None') && cookie.include?('secure')
    end
  ensure
    Account.current&.rollback(:same_site_none)
  end

  def test_action_dispatch_cookies_should_not_have_all_same_site_none_when_same_site_launched
    Account.current.rollback(:same_site_none)
    get '/api/_/contact_fields', nil, @headers
    assert_response 200
    cookie_header = response.headers['Set-Cookie'].split("\n")
    cookie_header.each do |cookie|
      assert_equal false, cookie.include?('SameSite=None') && cookie.include?('secure')
    end
  end

  def test_should_set_same_site_lax
    header = { 'Set-Cookie' => '' }
    Rack::Utils.set_cookie_header!(header, 'k', same_site: :lax)
    header['Set-Cookie'].must_equal 'k=; SameSite=Lax'
  end

  def test_should_set_same_site_strict
    header = { 'Set-Cookie' => '' }
    Rack::Utils.set_cookie_header!(header, 'k', same_site: true).must_be_nil
    header['Set-Cookie'].must_equal 'k=; SameSite=Strict'
  end

  def test_should_set_same_site_none
    header = { 'Set-Cookie' => '' }
    Rack::Utils.set_cookie_header!(header, 'k', same_site: :none).must_be_nil
    header['Set-Cookie'].must_equal 'k=; SameSite=None'
  end
end
