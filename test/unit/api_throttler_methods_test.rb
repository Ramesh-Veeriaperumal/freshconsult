require_relative '../test_helper'

class APIThrottlerMethodsTest < ActionView::TestCase
 include APIThrottlerMethods

  def test_allowed_api_limit_from_cache
    new_acc = mock('account')
    new_acc.stubs(:id).returns(1)
    new_acc.stubs(:api_limit).returns(200)
    self.stubs(:current_account).returns(new_acc)
    MemcacheKeys.stubs(:get_from_cache).returns(nil)
    assert_equal 200, allowed_api_limit  
    self.unstub(:current_account)
    MemcacheKeys.unstub(:get_from_cache)
  end

  def test_allowed_api_limit_cache_missed
    new_acc = mock('account_2')
    new_acc.stubs(:id).returns(1)
    self.stubs(:current_account).returns(new_acc)
    MemcacheKeys.stubs(:get_from_cache).returns(1000)
    assert_equal 1000, allowed_api_limit
    self.unstub(:current_account)
    MemcacheKeys.unstub(:get_from_cache)
  end

  def test_spent_api_limit
    new_acc = mock('account')
    new_acc.stubs(:id).returns(1)
    self.stubs(:current_account).returns(new_acc)
    self.stubs(:env).returns({})
    $redis_others.stubs(:get).returns(5)
    assert_equal 5, spent_api_limit  
    $redis_others.unstub(:get)
  end
end