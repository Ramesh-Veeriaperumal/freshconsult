require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'

Sidekiq::Testing.fake!

class GenerateSitemapTest < ActionView::TestCase

  include MemcacheKeys

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_generate_site_map_worker
    assert_nothing_raised do
      outdated_sitemap_key = SITEMAP_OUTDATED % { :account_id => @account.id }
      Community::GenerateSitemap.any_instance.stubs(:portal_redis_key_exists?).with(outdated_sitemap_key).returns(true)
      Community::GenerateSitemap.any_instance.expects(:remove_portal_redis_key).with(outdated_sitemap_key).once
      AwsWrapper::S3.expects(:put).times(@account.portals.count)
      Community::GenerateSitemap.new.perform(@account.id)
    end
  ensure
    Community::GenerateSitemap.any_instance.unstub(:portal_redis_key_exists?)
  end
end