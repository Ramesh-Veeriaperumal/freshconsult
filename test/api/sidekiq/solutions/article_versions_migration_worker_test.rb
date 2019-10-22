require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require "#{Rails.root}/test/core/helpers/solutions_test_helper.rb"
require "#{Rails.root}/test/api/helpers/solutions_articles_test_helper.rb"

class ArticleVersionsMigrationWorkerTest < ActionView::TestCase
  include CoreSolutionsTestHelper
  include SolutionsArticlesTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    setup_articles
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def setup_articles
    category_meta = create_category
    folder_meta = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category_meta.id)
    populate_articles(folder_meta)
  end

  def test_add_article_version
    Sidekiq::Testing.inline! do
      @account.solution_article_versions.map(&:destroy)
      Solution::ArticleVersionsMigrationWorker.perform_async(account_id: @account.id, action: 'add')
      @account.reload
      assert_equal @account.solution_articles.where(status: Solution::Article::STATUS_KEYS_BY_TOKEN[:published]).count + @account.solution_drafts.count, @account.solution_article_versions.count
    end
  end

  def test_drop_article_version
    Sidekiq::Testing.inline! do
      @account.solution_article_versions.map(&:destroy)
      Solution::ArticleVersionsMigrationWorker.perform_async(account_id: @account.id, action: 'add')
      @account.reload
      assert_equal @account.solution_articles.where(status: Solution::Article::STATUS_KEYS_BY_TOKEN[:published]).count + @account.solution_drafts.count, @account.solution_article_versions.count
      Solution::ArticleVersionsMigrationWorker.perform_async(account_id: @account.id, action: 'drop')
      @account.reload
      assert_equal 0, @account.reload.solution_article_versions.count
    end
  end

  def test_drop_acticle_version_with_exception
    Sidekiq::Testing.inline! do
      @account.solution_article_versions.map(&:destroy)
      Solution::ArticleVersionsMigrationWorker.perform_async(account_id: @account.id, action: 'add')
      @account.reload
      assert_equal @account.solution_articles.where(status: Solution::Article::STATUS_KEYS_BY_TOKEN[:published]).count + @account.solution_drafts.count, @account.solution_article_versions.count
      assert_nothing_raised do
        Solution::ArticleVersion.any_instance.stubs(:destroy).raises(StandardError)
        Solution::ArticleVersionsMigrationWorker.perform_async(account_id: @account.id, action: 'drop')
      end
      @account.reload
      assert_equal @account.solution_articles.where(status: Solution::Article::STATUS_KEYS_BY_TOKEN[:published]).count + @account.solution_drafts.count, @account.solution_article_versions.count
    end
  ensure
    Solution::ArticleVersion.any_instance.unstub(:destroy)
  end

  def test_add_acticle_version_with_exception
    Sidekiq::Testing.inline! do
      Solution::ArticleVersionsMigrationWorker.any_instance.stubs(:safe_send).with('add_versions').raises(StandardError)
      NewRelic::Agent.expects(:notice_error).once
      Solution::ArticleVersionsMigrationWorker.perform_async(account_id: @account.id, action: 'add')
    end
  ensure
    Solution::ArticleVersionsMigrationWorker.any_instance.unstub(:safe_send)
  end

  def test_add_acticle_version_with_exception_in_version_create
    Sidekiq::Testing.inline! do
      assert_nothing_raised do
        Solution::ArticleVersionsMigrationWorker.any_instance.stubs(:version_create_or_update).raises(StandardError)
        Solution::ArticleVersionsMigrationWorker.perform_async(account_id: @account.id, action: 'add')
      end
    end
  ensure
    Solution::ArticleVersionsMigrationWorker.any_instance.unstub(:version_create_or_update)
  end

  def test_add_article_version_without_duplicate
    Sidekiq::Testing.inline! do
      @account.solution_article_versions.map(&:destroy)
      Solution::ArticleVersionsMigrationWorker.perform_async(account_id: @account.id, action: 'add')
      assert_equal  @account.solution_articles.where(status: Solution::Article::STATUS_KEYS_BY_TOKEN[:published]).count + @account.solution_drafts.count, @account.solution_article_versions.count
      # if version is already available for all articles it shouldn't create new version
      Solution::ArticleVersionsMigrationWorker.any_instance.expects(:version_create_or_update).never
      Solution::ArticleVersionsMigrationWorker.perform_async(account_id: @account.id, action: 'add')
    end
  end
end
