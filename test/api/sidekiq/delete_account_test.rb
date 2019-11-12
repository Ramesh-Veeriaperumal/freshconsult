require_relative '../unit_test_helper'
require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

require 'sidekiq/testing'
Sidekiq::Testing.fake!
class DeleteAccountTest < ActionView::TestCase
  include AccountTestHelper
  include FreshdeskCore::Model
  include Mysql::RecordsHelper

  def setup
    account = create_new_account(Faker::Internet.domain_word.to_s, Faker::Internet.email)
    Account.stubs(:current).returns(account)
    Account.any_instance.stubs(:manual_publish_to_central).returns(true)
    Social::FacebookPage.any_instance.stubs(:unsubscribe_realtime).returns(true)
    Social::FacebookPage.any_instance.stubs(:cleanup).returns(true)
    SendgridDomainUpdates.any_instance.stubs(:perform).returns(true)
  end

  def teardown
    super
  end

  def test_account_delete
    account_id = Account.current.id
    account = Account.current
    account.subscription.state = 'suspended'
    account.save!
    args = { account_id: account_id }
    Sidekiq::Testing.inline! do
      AccountCleanup::DeleteAccount.new.perform(args)
    end
    account_after_delete = Account.find_by_id(account_id)
    assert_nil account_after_delete
    assert_all_tables_cleaned_up(account_id)
  ensure
    account_after_delete.destroy if account_after_delete
  end

  def assert_all_tables_cleaned_up(account_id)
    all_tables = HELPKIT_TABLES + HELPKIT_TABLES_AND_COMPOSITE_KEYS.keys
    all_tables.each do |table_name|
      query = "select count(*) from #{table_name} where account_id = #{account_id}"
      count = ActiveRecord::Base.connection.select_values(query).first
      assert_equal 0, count
    end
  end
end
