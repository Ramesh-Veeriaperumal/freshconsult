require_relative '../../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'solutions_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'solutions_articles_test_helper.rb')

class ArticleReindexWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include CoreSolutionsTestHelper
  include SolutionsArticlesTestHelper
  include CoreUsersTestHelper

  def setup
    setup_redis_for_articles
    @account = Account.first
    Account.stubs(:current).returns(@account || create_test_account)
    @agent = add_test_agent
    5.times do
      create_article
    end
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def freeze_time
    time = Time.zone.now
    Timecop.freeze(time)
    yield
    Timecop.return
  end

  def test_article_reindex_worker
    Sidekiq::Testing.inline! do
      assert_nothing_raised do
        Search::Analytics::ArticleReindexWorker.perform_async({})
      end
    end
  end

  def test_last_indexed_time
    Sidekiq::Testing.inline! do
      freeze_time do
        Search::V2::Operations::DocumentAdd.any_instance.stubs(:perform).returns(true)
        Search::Analytics::ArticleReindexWorker.perform_async({})
        assert @account.account_additional_settings.additional_settings[:last_article_reindexed_time]
        assert_instance_of Time, @account.account_additional_settings.additional_settings[:last_article_reindexed_time]
      end
    end
  ensure
    Search::V2::Operations::DocumentAdd.any_instance.unstub(:perform)
  end

  def test_article_reindex_worker_exception
    Sidekiq::Testing.inline! do
      Search::Analytics::ArticleReindexWorker.any_instance.stubs(:safe_send).with('perform').raises(StandardError)
      NewRelic::Agent.expects(:notice_error).at_least_once
      Search::Analytics::ArticleReindexWorker.perform_async({})
    end
  ensure
    Search::Analytics::ArticleReindexWorker.any_instance.unstub(:safe_send)
  end
end
