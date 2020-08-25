require_relative '../../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class SearchService::ClientTest < ActionView::TestCase
  include AccountTestHelper
  def setup
    super
    @account = Account.first || create_test_account
    Account.stubs(:current).returns(@account)
  end

  def test_support_search_for_japanese_language
    Account.any_instance.stubs(:language).returns('ja-JP')
    SearchService::Client.any_instance.stubs(:fetch_uuid).returns('1234')
    SearchService::Client.any_instance.stubs(:tenants_path).returns('https://testing.com/search')
    SearchService::Client.any_instance.stubs(:request_headers).returns('X-Request-Id': '1234', 'X-Amzn-Trace-Id': 'Root=1234')
    SearchService::Request.any_instance.stubs(:handle_failure).returns(nil)
    mock = MiniTest::Mock.new
    item_hash = { response: 'description' }
    item = OpenStruct.new item_hash
    mock.expect(:call, item, ['https://testing.com/search', :post, '1234', { id: @account.id, language: 'ja-JP' }.to_json, { 'X-Request-Id': '1234', 'X-Amzn-Trace-Id': 'Root=1234' }, @account.id])
    SearchService::Request.stub :new, mock do
      SearchService::Client.new(@account.id).tenant_bootstrap
    end
    mock.verify
  ensure
    Account.any_instance.unstub(:language)
  end

  def test_support_search_for_nonjapanese_language
    SearchService::Client.any_instance.stubs(:fetch_uuid).returns('1234')
    SearchService::Client.any_instance.stubs(:tenants_path).returns('https://testing.com/search')
    SearchService::Client.any_instance.stubs(:request_headers).returns('X-Request-Id': '1234', 'X-Amzn-Trace-Id': 'Root=1234')
    SearchService::Request.any_instance.stubs(:handle_failure).returns(nil)
    mock = MiniTest::Mock.new
    item_hash = { response: 'description' }
    item = OpenStruct.new item_hash
    mock.expect(:call, item, ['https://testing.com/search', :post, '1234', { id: @account.id }.to_json, { 'X-Request-Id': '1234', 'X-Amzn-Trace-Id': 'Root=1234' }, @account.id])
    SearchService::Request.stub :new, mock do
      SearchService::Client.new(@account.id).tenant_bootstrap
    end
    mock.verify
  end
end
