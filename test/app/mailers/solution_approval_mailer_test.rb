require_relative '../../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'solutions_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'solutions_articles_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'solutions_approvals_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

class SolutionApprovalMailerTest < ActionView::TestCase

  include CoreSolutionsTestHelper
  include SolutionsArticlesTestHelper
  include SolutionsApprovalsTestHelper
  include CoreUsersTestHelper

  def setup
    super
    @account = create_test_account if @account.nil?
    @account.make_current
    @requester = add_test_agent
    @agent = add_test_agent
    @agent.make_current
    setup_articles
  end

  def teardown
    @agent.destroy
    @requester.destroy
  end

  def setup_articles
    category_meta = create_category
    folder_meta = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category_meta.id)
    populate_articles(folder_meta)
  end

  def test_in_review_with_one_user
    article = get_in_review_article(Account.current.language_object, @agent, @requester)
    assert_nothing_raised do
      ::SolutionApprovalMailer.any_instance.expects(:construct_in_review_mail).once
      ::SolutionApprovalMailer.notify_approval(Solution::ApproverMapping.new(get_approver_mapping(article)), [@agent])
    end
  end

  def test_approved_with_one_user
    article = get_approved_article(Account.current.language_object, @agent, @requester)
    assert_nothing_raised do
      ::SolutionApprovalMailer.any_instance.expects(:construct_in_review_mail).times(0)
      ::SolutionApprovalMailer.any_instance.expects(:construct_approved_mail).once
      ::SolutionApprovalMailer.notify_approval(Solution::ApproverMapping.new(get_approver_mapping(article)), [@agent])
    end
  end

  def test_approved_with_two_users
    article = get_approved_article(Account.current.language_object, @agent, @requester)
    @agent.update_attributes(language: 'de')
    assert_nothing_raised do
      ::SolutionApprovalMailer.any_instance.expects(:construct_in_review_mail).times(0)
      ::SolutionApprovalMailer.any_instance.expects(:construct_approved_mail).times(2)
      ::SolutionApprovalMailer.notify_approval(Solution::ApproverMapping.new(get_approver_mapping(article)), [@agent, @requester])
    end
  end

  private

    def get_approver_mapping(article)
      article.helpdesk_approval.approver_mappings.first
    end
end
