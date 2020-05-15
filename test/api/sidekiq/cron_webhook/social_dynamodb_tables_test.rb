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
    $dynamo_v2_client.stubs(:create_table).returns({})
    $dynamo_v2_client.stubs(:describe_table).returns(table: { table_status: 'CREATED' })
    assert CronWebhooks::SocialCreateDynamodbTables.new.perform(task_name: 'social_create_dynamoDb_tables')
  ensure
    $dynamo_v2_client.unstub(:describe_table)
    $dynamo_v2_client.unstub(:create_table)
    Social::DynamoHelper.unstub(:table_exists?)
  end

  def test_delete_dynamo_tables
    Social::DynamoHelper.stubs(:table_exists?).returns(true)
    $dynamo_v2_client.stubs(:delete_table).returns({})
    $dynamo_v2_client.stubs(:describe_table).returns(table: { table_status: 'DELETED' })
    assert CronWebhooks::SocialDeleteDynamodbTables.new.perform(task_name: 'social_delete_dynamoDb_tables')
  ensure
    $dynamo_v2_client.unstub(:describe_table)
    $dynamo_v2_client.unstub(:delete_table)
    Social::DynamoHelper.unstub(:table_exists?)
  end
end
