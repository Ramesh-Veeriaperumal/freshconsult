require 'test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')
require_relative 'helpers/facebook_test_helper.rb'

class Admin::Social::FacebookStreamsControllerTest < ActionController::TestCase
  include FacebookTestHelper

  def setup
    @account = Account.first || create_test_account
    Account.any_instance.stubs(:current).returns(@account)
    super
  end

  def teardown
    Account.any_instance.unstub(:current)
    super
  end

  def test_index_page_load
    Facebook::Oauth::FbClient.any_instance.stubs(:authorize_url).returns(sample_callback_url)
    Facebook::Oauth::FbClient.any_instance.stubs(:auth).returns(sample_fb_page)
    HTTParty.stubs(:get).returns(sample_gateway_page_detail, true)
    get :index
    assert_response 200
  end

  def test_fb_rule_optimal_filter_mentions_enabled
    fb_page = create_test_facebook_page(@account)
    fb_page.stubs(:unregister_stream_subscription).returns(true)
    fb_ticket_rule = fb_page.default_ticket_rule
    params = optimal_rule_params(fb_page.default_stream.id, fb_ticket_rule.id)
    put :update, params
    assert_response 302
    fb_page.reload
    fb_tkt_rule = fb_page.default_ticket_rule
    assert_equal true, fb_tkt_rule.optimal?
    assert_equal true, fb_tkt_rule.filter_mentions?
  ensure
    fb_page.destroy
  end

  def test_fb_rule_broad_filter_mentions_enabled
    fb_page = create_test_facebook_page(@account)
    fb_page.stubs(:unregister_stream_subscription).returns(true)
    fb_ticket_rule = fb_page.default_ticket_rule
    params = broad_rule_params(fb_page.default_stream.id, fb_ticket_rule.id)
    put :update, params
    assert_response 302
    fb_page.reload
    fb_tkt_rule = fb_page.default_ticket_rule
    assert_equal true, fb_tkt_rule.broad?
    assert_equal true, fb_tkt_rule.filter_mentions?
  ensure
    fb_page.destroy
  end

  def test_fb_rule_ad_post_filter_mentions_enabled
    fb_page = create_test_facebook_page(@account)
    fb_page.stubs(:unregister_stream_subscription).returns(true)
    fb_ticket_rule = fb_page.default_ticket_rule
    params = optimal_rule_params(fb_page.default_stream.id, fb_ticket_rule.id).merge(ad_posts_params)
    put :update, params
    assert_response 302
    fb_page.reload
    ad_post_rule = fb_page.ad_post_stream.facebook_ticket_rules.first
    assert_equal true, ad_post_rule.filter_mentions?
  ensure
    fb_page.destroy
  end

end
