require_relative '../test_helper'
require 'faker'
require Rails.root.join('test', 'core', 'helpers', 'facebook_page_test_helper.rb')

class FacebookPageTest < ActiveSupport::TestCase
  include FacebookPageTestHelper
  include CentralLib::Util

  def test_central_payload
    account = Account.current
    new_fb_page = account.facebook_pages.new(sample_fb_page)
    new_fb_page.save
    payload = new_fb_page.central_publish_payload
    expected_payload = central_payload(new_fb_page)
    payload.must_match_json_expression(expected_payload)
  end
end
