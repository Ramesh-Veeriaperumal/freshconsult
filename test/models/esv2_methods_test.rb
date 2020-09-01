require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require "#{Rails.root}/test/api/helpers/solutions_articles_test_helper.rb"

class Esv2MethodTest < ActiveSupport::TestCase
  include SolutionsApprovalsTestHelper
  include AccountTestHelper
  include CoreSolutionsTestHelper
  include SolutionsArticlesTestHelper
  include SolutionsPlatformsTestHelper

  def setup
    create_test_account if @account.nil?
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

  def test_approver_ids_pushed_to_search_if_approval_workflow_enabled
    Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
    article = get_in_review_article
    payload = JSON.parse(article.to_esv2_json)
    assert_equal payload['approvers'], article.helpdesk_approval.approver_mappings.pluck(:approver_id)
  ensure
    Account.any_instance.unstub(:article_approval_workflow_enabled?)
  end

  def test_approver_ids_not_pushed_to_search_if_approval_workflow_not_enabled
    Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(false)
    article = get_in_review_article
    payload = JSON.parse(article.to_esv2_json)
    refute_includes payload, 'approvers'
  ensure
    Account.any_instance.unstub(:article_approval_workflow_enabled?)
  end

  def test_platforms_pushed_to_search_if_omni_enabled
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    article = get_article_with_platform_mapping
    payload = JSON.parse(article.to_esv2_json)
    assert_equal payload['platforms'], article.parent.solution_platform_mapping.enabled_platforms
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
  end

  def test_platforms_not_pushed_to_search_if_omni_disabled
    article = get_article_with_platform_mapping
    payload = JSON.parse(article.to_esv2_json)
    refute_includes payload, 'platforms'
  end
end
