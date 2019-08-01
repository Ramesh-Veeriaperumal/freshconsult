require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../test_transactions_fixtures_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
Sidekiq::Testing.fake!
class SitemapGeneratorTest < ActionView::TestCase
  include AccountTestHelper

  def teardown
    super
    Account.unstub(:current)
    Redis::PortalRedis.unstub(:portal_redis_key_exists?)
  end

  def setup
    @account = create_test_account if Account.first.nil?
  end

  def test_site_map_genrator
    Community::GenerateSitemap.drain
    Account.any_instance.stubs(:sitemap_enabled?).returns(true)
    Redis::PortalRedis.stubs(:portal_redis_key_exists?).returns(true)
    CronWebhooks::SitemapGenerate.new.perform(task_name: 'sitemap_generate')
    assert_equal true, Community::GenerateSitemap.jobs.size >= 1, 'Should enqueue site map jobs'
  end

  def test_site_map_genrator_no_enqueue
    Community::GenerateSitemap.drain
    Account.any_instance.stubs(:sitemap_enabled?).returns(false)
    CronWebhooks::SitemapGenerate.new.perform(task_name: 'sitemap_generate')
    assert_equal 0, Community::GenerateSitemap.jobs.size, 'Site map generators should not get enqueued'
  end
end
