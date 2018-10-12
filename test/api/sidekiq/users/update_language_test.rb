require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class UpdateLanguageTest < ActionView::TestCase

  include AccountTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @user = create_dummy_customer
    @user.language = 'es'
    @user.save
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_update_language_worker
    assert_nothing_raised do
      assert_not_equal get_not_matching_users_count, 0
      Users::UpdateLanguage.new.perform({})
      assert_equal get_not_matching_users_count, 0
    end
  end


  def test_update_language_worker_exception
    assert_raises(RuntimeError) do
      Account.any_instance.stubs(:language).raises(RuntimeError)
      Users::UpdateLanguage.new.perform({})
    end
  ensure
    Account.any_instance.unstub(:language)
  end

  private

  def get_not_matching_users_count
    @account.all_users.where("language != ?", @account.language).size
  end
end