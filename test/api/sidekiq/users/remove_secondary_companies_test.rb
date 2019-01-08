require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class RemoveSecondaryCompaniesTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @user = @account.users.first
    3.times do
      @user.companies.build(name: Faker::Name.name)
    end
    @user.save
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_secondary_companies_removed
    sample_user = @user
    sample_user.user_companies.first['default'] = true
    sample_user.save
    Users::RemoveSecondaryCompanies.new.perform
    sample_user.reload
    assert_equal sample_user.companies.count, 1
  end
end
