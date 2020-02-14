require_relative '../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'solutions_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'solutions_articles_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'solutions_approvals_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

class DeleteSolutionMetaWorkerTest < ActionView::TestCase
  include CoreSolutionsTestHelper
  include SolutionsArticlesTestHelper
  include SolutionsApprovalsTestHelper
  include ControllerTestHelper
  include CoreUsersTestHelper

  def setup
    setup_redis_for_articles
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @requester = add_test_agent
    @agent = add_test_agent
    @agent.make_current
    setup_articles
  end

  def teardown
    Account.unstub(:current)
    User.reset_current_user
    super
  end

  def setup_articles
    @category_meta = create_category
    @folder_meta = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: @category_meta.id)
    populate_articles(@folder_meta)
  end

  def test_job_push_and_article_meta_deletion
    DeleteSolutionMetaWorker.any_instance.stubs(:get_replication_lag_for_shard).returns(-1)
    assert_not_equal 0, Account.current.solution_article_meta.where(solution_folder_meta_id: @folder_meta.id).size
    assert_nothing_raised do
      Sidekiq::Testing.inline! do
        DeleteSolutionMetaWorker.perform_async(parent_level_id: @folder_meta.id, object_type: 'folder_meta')
      end
    end
    assert_equal 0, Account.current.solution_article_meta.where(solution_folder_meta_id: @folder_meta.id).size
  end

  def test_job_push_and_folder_meta_deletion
    DeleteSolutionMetaWorker.any_instance.stubs(:get_replication_lag_for_shard).returns(-1)
    assert_not_equal 0, Solution::FolderMeta.where(solution_category_meta_id: @category_meta.id, account_id: Account.current).size
    assert_nothing_raised do
      Sidekiq::Testing.inline! do
        DeleteSolutionMetaWorker.perform_async(parent_level_id: @category_meta.id, object_type: 'category_meta')
      end
    end
    assert_equal 0, Solution::FolderMeta.where(solution_category_meta_id: @category_meta.id, account_id: Account.current).size
  end

  def test_article_meta_deletion_when_category_meta_is_deleted
    DeleteSolutionMetaWorker.any_instance.stubs(:get_replication_lag_for_shard).returns(-1)
    assert_not_equal 0, Account.current.solution_article_meta.where(solution_folder_meta_id: @folder_meta.id).size
    assert_nothing_raised do
      Sidekiq::Testing.inline! do
        DeleteSolutionMetaWorker.perform_async(parent_level_id: @category_meta.id, object_type: 'category_meta')
      end
    end
    assert_equal 0, Account.current.solution_article_meta.where(solution_folder_meta_id: @folder_meta.id).size
  end

  def test_delete_empty_category
    DeleteSolutionMetaWorker.any_instance.stubs(:get_replication_lag_for_shard).returns(-1)
    category_meta_without_folder = create_category
    assert_equal 0, Solution::FolderMeta.where(solution_category_meta_id: category_meta_without_folder.id, account_id: Account.current).size
    assert_nothing_raised do
      Sidekiq::Testing.inline! do
        DeleteSolutionMetaWorker.perform_async(parent_level_id: category_meta_without_folder.id, object_type: 'category_meta')
      end
    end
  end

  def test_delete_empty_folder
    DeleteSolutionMetaWorker.any_instance.stubs(:get_replication_lag_for_shard).returns(-1)
    category_meta_with_folder = create_category
    folder_meta_without_article = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category_meta_with_folder.id)
    assert_equal 0, Account.current.solution_article_meta.where(solution_folder_meta_id: folder_meta_without_article.id).size
    assert_nothing_raised do
      Sidekiq::Testing.inline! do
        DeleteSolutionMetaWorker.perform_async(parent_level_id: folder_meta_without_article.id, object_type: 'folder_meta')
      end
    end
  end
end
