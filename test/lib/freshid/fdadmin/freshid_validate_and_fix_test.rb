require_relative '../../test_helper'
require 'minitest/spec'

class FreshidValidateAndFixTest < ActiveSupport::TestCase
  include Redis::RedisKeys
  include Redis::OthersRedis
  def setup
    super
    @test_obj = Freshid::Fdadmin::FreshidValidateAndFix.new('sample-no-reply-invalid@freshdesk.dev')
    Account.stubs(:current).returns(Account.first)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_account_validation_timeout
    mock = Minitest::Mock.new
    mock.expect(:call, true, ["Freshid Validation :: Started validation for a=#{Account.current.id}"])
    Rails.logger.stub :info, mock do
      @test_obj.account_validation
    end
    assert_equal mock.verify, true
    redis_key = format(FRESHID_VALIDATION_TIMEOUT, account_id: Account.current.id.to_s)
    assert_equal get_others_redis_key(redis_key), true.to_s
  end
end
