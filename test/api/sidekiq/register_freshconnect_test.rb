require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'webmock/minitest'
WebMock.allow_net_connect!
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class RegisterFreshconnectTest < ActionView::TestCase
  include AccountTestHelper
  SUCCESS = 200..299

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def test_register_freshconnect_with_success_status
    @account.freshconnect_account.destroy if @account.freshconnect_account.present?
    stub_request(:post, %r{^http://localhost:8888.*?$}).to_return(body: stub_response.to_json, status: 200)
    ::Freshconnect::RegisterFreshconnect.new.perform
    @account.reload
    assert_equal true, @account.freshconnect_enabled?
    Account.unstub(:current)
  end

  def test_register_freshconnect_with_failed_status
    @account.freshconnect_account.destroy if @account.freshconnect_account.present?
    stub_request(:post, %r{^http://localhost:8888.*?$}).to_return(status: 400)
    ::Freshconnect::RegisterFreshconnect.new.perform
    @account.reload
    assert_equal false, @account.freshconnect_enabled?
    Account.unstub(:current)
  end

  private

    def stub_response
      { product_account_id: Random.rand(11).to_s,
        enabled: true,
        domain: [Faker::Lorem.characters(10), 'freshconnect', 'com'].join('.') }
    end
end
