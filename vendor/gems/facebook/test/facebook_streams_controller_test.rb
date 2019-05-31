require 'test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')
require_relative 'helpers/facebook_test_helper.rb'

class Admin::Social::FacebookStreamsControllerTest < ActionController::TestCase
  include FacebookTestHelper

  def test_index_page_load
    Facebook::Oauth::FbClient.any_instance.stubs(:authorize_url).returns(sample_callback_url)
    Facebook::Oauth::FbClient.any_instance.stubs(:auth).returns(sample_fb_page)
    HTTParty.stubs(:get).returns(sample_gateway_page_detail, true)
    get :index
    assert_response 200
  end
end
