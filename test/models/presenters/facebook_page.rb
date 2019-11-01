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

  def test_prevent_central_publish_for_update_in_message_since
    CentralPublisher::Worker.jobs.clear
    account = Account.current
    fb_page = account.facebook_pages.new(sample_fb_page)
    fb_page.save
    assert_equal 1, CentralPublisher::Worker.jobs.size
    CentralPublisher::Worker.jobs.clear
    fb_page.message_since = Faker::Number.number(5).to_i
    fb_page.save
    assert_equal 0, CentralPublisher::Worker.jobs.size
  end
  
  def test_prevent_central_publish_for_update_in_fetch_since
    CentralPublisher::Worker.jobs.clear
    account = Account.current
    fb_page = account.facebook_pages.new(sample_fb_page)
    fb_page.save
    assert_equal 1, CentralPublisher::Worker.jobs.size
    CentralPublisher::Worker.jobs.clear
    fb_page.fetch_since = Faker::Number.number(5).to_i
    fb_page.save
    assert_equal 0, CentralPublisher::Worker.jobs.size
  end

  def test_central_publish_for_update_in_facebook_pages
    CentralPublisher::Worker.jobs.clear    
    account = Account.current
    fb_page = account.facebook_pages.new(sample_fb_page)
    fb_page.save
    assert_equal 1, CentralPublisher::Worker.jobs.size
    CentralPublisher::Worker.jobs.clear
    fb_page.product_id = Faker::Number.number(5).to_i
    fb_page.save
    assert_equal 1, CentralPublisher::Worker.jobs.size
    CentralPublisher::Worker.jobs.clear
    fb_page.message_since = Faker::Number.number(5).to_i
    fb_page.product_id = Faker::Number.number(5).to_i
    fb_page.save
    assert_equal 1, CentralPublisher::Worker.jobs.size
  end  


end
