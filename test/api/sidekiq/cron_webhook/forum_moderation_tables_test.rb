require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

Sidekiq::Testing.fake!

class ForumModerationTablesTest < ActionView::TestCase
  include AccountTestHelper
  include CoreUsersTestHelper

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.current
    @user = @account.nil? ? create_test_account : add_new_user(@account)
    @user.make_current
  end

  def test_forum_moderation_create_tables
    Community::DynamoTables.expects(:create).once
    CronWebhooks::ForumModerationCreateTables.new.perform(task_name: 'forum_moderation_create_tables')
  end

  def test_forum_moderation_drop_tables
    Community::DynamoTables.expects(:drop).once
    CronWebhooks::ForumModerationDropTables.new.perform(task_name: 'forum_moderation_drop_tables')
  end
end
