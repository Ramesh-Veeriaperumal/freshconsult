require_relative '../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class AccountDetailsDestroyWorkerTest < ActionView::TestCase

  def test_account_details_destroy_no_exceptions
    assert_nothing_raised do
      Email::AccountDetailsDestroyWorker.new.perform({:account=>'1',:account_domain => 'Test.com'})
    end
  end

  def test_account_details_destroy_with_exceptions
    assert_nothing_raised do
      Email::AccountDetailsDestroyWorker.new.perform({:account=>1,:account_domain => 'Test.com'})
    end
  end

end