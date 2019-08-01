require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

Sidekiq::Testing.fake!

class LongRunningQueriesCheckTest < ActionView::TestCase
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

  def set_constant(value)
    CronWebhooks::LongRunningQueriesCheck.send(:remove_const, :LONG_RUNNING_QUERIES_THRESHOLD)
    CronWebhooks::LongRunningQueriesCheck.const_set(:LONG_RUNNING_QUERIES_THRESHOLD, value)
  end

  def with_necessary_stubs
    sample_data = ActiveRecord::Base.connection.exec_query('select * from accounts')
    ActiveRecord::Base.stubs(:supports_sharding?).returns(false)
    ActiveRecord::Base.connection.stubs(:exec_query).returns(sample_data)
    FreshdeskErrorsMailer.stubs(:error_email).returns(true)

    yield

    FreshdeskErrorsMailer.unstub(:error_email)
    ActiveRecord::Base.connection.unstub(:exec_query)
    ActiveRecord::Base.unstub(:supports_sharding?)
  end

  def test_long_running_queries_check
    with_necessary_stubs do
      old_threshold = CronWebhooks::LongRunningQueriesCheck.const_get(:LONG_RUNNING_QUERIES_THRESHOLD)
      set_constant(0)
      FreshdeskErrorsMailer.expects(:error_email).once
      CronWebhooks::LongRunningQueriesCheck.new.perform(task_name: 'long_running_queries_check')
      set_constant(old_threshold)
    end
  end
end
