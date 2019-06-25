require 'test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')
require_relative 'helpers/facebook_test_helper.rb'

class Admin::Social::FacebookPagesControllerTest < ActionController::TestCase
  include FacebookTestHelper

  def test_enable_pages
    Facebook::Oauth::FbClient.any_instance.stubs(:authorize_url).returns(sample_callback_url)
    Facebook::Oauth::FbClient.any_instance.stubs(:auth).returns(sample_fb_page)
    HTTParty.stubs(:get).returns(sample_gateway_page_detail, true)
    put :enable_pages, enable: { pages: sample_fb_page.map(&:to_json) }
    assert_response 302
  end
end
