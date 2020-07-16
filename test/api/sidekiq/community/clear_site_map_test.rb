require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'

Sidekiq::Testing.fake!

class ClearSiteMapTest < ActionView::TestCase

  include MemcacheKeys

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_clear_site_map_worker
    assert_nothing_raised do
      MemcacheKeys.expects(:delete_from_cache).with(SITEMAP_KEY % { :account_id => @account.id, :portal_id => @account.main_portal.id }).once
      AwsWrapper::S3Object.expects(:delete).with("sitemap/#{@account.id}/#{@account.main_portal.id}.xml", S3_CONFIG[:bucket]).once
      Community::ClearSitemap.new.perform(@account.id, @account.main_portal.id)
    end
  end
end