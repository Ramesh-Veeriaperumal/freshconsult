require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'
Sidekiq::Testing.fake!

class EmptyModerationTrashTest < ActionView::TestCase

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_worker
    assert_nothing_raised do
      Community::EmptyModerationTrash.new.perform
    end
  end
end