require_relative '../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'solutions_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'solutions_articles_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'solutions_platforms_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

class UpdateArticlePlatformMappingWorkerTest < ActionView::TestCase
  include CoreSolutionsTestHelper
  include SolutionsArticlesTestHelper
  include ControllerTestHelper
  include CoreUsersTestHelper
  include CoreSolutionsTestHelper
  include SolutionsPlatformsTestHelper

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
    platform_mapping_folder = { ios: true, web: true, android: false }
    platform_mapping_article = { ios: true, web: true, android: true }
    @folder = get_folder_with_platform_mapping(platform_mapping_folder)
    @disabled_platforms = platform_mapping_folder.select { |platform, enabled| enabled == false }
    (1..7).each do |i|
      # Load 70 articles
      populate_articles_with_platform_mapping(@folder.parent, platform_mapping_article)
    end
  end

  def populate_articles_with_platform_mapping(folder_meta, platform_mapping)
    (1..10).each do |i|
      articlemeta = create_article({ folder_meta_id: folder_meta.id })
      articlemeta.build_solution_platform_mapping(platform_mapping)
      articlemeta.save
    end
  end

  def test_article_platform_update_with_folder_platform_disabled
    UpdateArticlePlatformMappingWorkerTest.any_instance.stubs(:get_replication_lag_for_shard).returns(-1)
    assert_not_equal 0, Account.current.solution_platform_mappings.joins(["INNER JOIN solution_article_meta ON solution_platform_mappings.mappable_id = solution_article_meta.id AND solution_platform_mappings.account_id = solution_article_meta.account_id AND solution_article_meta.solution_folder_meta_id = #{@folder.parent_id}"]).where('mappable_type = ? AND android = ?', 'Solution::ArticleMeta', true).size
    assert_nothing_raised do
      Sidekiq::Testing.inline! do
        UpdateArticlePlatformMappingWorker.perform_async(parent_level_id: @folder.parent_id, object_type: 'folder_meta', disabled_folder_platforms: @disabled_platforms)
      end
    end
    assert_equal 0, Account.current.solution_platform_mappings.joins(["INNER JOIN solution_article_meta ON solution_platform_mappings.mappable_id = solution_article_meta.id AND solution_platform_mappings.account_id = solution_article_meta.account_id AND solution_article_meta.solution_folder_meta_id = #{@folder.parent_id}"]).where('mappable_type = ? AND android = ?', 'Solution::ArticleMeta', true).size
  end

  def test_delete_article_platform_mapping
    UpdateArticlePlatformMappingWorkerTest.any_instance.stubs(:get_replication_lag_for_shard).returns(-1)
    assert_not_equal 0, Account.current.solution_platform_mappings.joins(["INNER JOIN solution_article_meta ON solution_platform_mappings.mappable_id = solution_article_meta.id AND solution_platform_mappings.account_id = solution_article_meta.account_id AND solution_article_meta.solution_folder_meta_id = #{@folder.parent_id}"]).where(mappable_type: 'Solution::ArticleMeta').size
    assert_nothing_raised do
      Sidekiq::Testing.inline! do
        UpdateArticlePlatformMappingWorker.perform_async(parent_level_id: @folder.parent_id, object_type: 'folder_meta')
      end
    end
    assert_equal 0, Account.current.solution_platform_mappings.joins(["INNER JOIN solution_article_meta ON solution_platform_mappings.mappable_id = solution_article_meta.id AND solution_platform_mappings.account_id = solution_article_meta.account_id AND solution_article_meta.solution_folder_meta_id = #{@folder.parent_id}"]).where(mappable_type: 'Solution::ArticleMeta').size
  end
end
