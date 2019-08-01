require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

Sidekiq::Testing.fake!

class SocialDynamodbTablesTest < ActionView::TestCase
  include AccountTestHelper
  include CoreUsersTestHelper
  include Social::Constants

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.current
    @user = @account.nil? ? create_test_account : add_new_user(@account)
    @user.make_current
  end

  def test_create_dynamo_tables
    Social::DynamoHelper.stubs(:table_exists?).returns(false)
    $social_dynamoDb.expects(:create_table)
    CronWebhooks::SocialCreateDynamodbTables.new.perform(task_name: 'social_create_dynamoDb_tables')
    Social::DynamoHelper.unstub(:table_exists?)
  end

  def test_delete_dynamo_tables
    Social::DynamoHelper.stubs(:table_exists?).returns(true)
    $social_dynamoDb.expects(:delete_table)
    CronWebhooks::SocialDeleteDynamodbTables.new.perform(task_name: 'social_delete_dynamoDb_tables')
    Social::DynamoHelper.unstub(:table_exists?)
  end

  def test_increase_dynamo_capacity
    $social_dynamoDb.expects(:update_table)
    CronWebhooks::SocialIncreaseDynamodbCapacity.new.perform(task_name: 'social_increase_dynamoDb_capacity')
  end

  def test_reduce_dynamo_capacity
    $social_dynamoDb.expects(:update_table)
    CronWebhooks::SocialReduceDynamodbCapacity.new.perform(task_name: 'social_reduce_dynamoDb_capacity')
  end
end
