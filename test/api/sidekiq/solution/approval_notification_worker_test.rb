require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'solutions_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'solutions_articles_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'solutions_approvals_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

class ApprovalNotificationWorkerTest < ActionView::TestCase
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
    category_meta = create_category
    folder_meta = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category_meta.id)
    populate_articles(folder_meta)
  end

  def test_send_in_review_notifications
    article = get_in_review_article(Account.current.language_object, @agent, @requester)
    ::Solution::ApprovalNotificationWorker.any_instance.expects(:push_data_to_service).once
    ::SolutionApprovalMailer.expects(:notify_approval).once
    Sidekiq::Testing.inline! do
      ::Solution::ApprovalNotificationWorker.perform_async(id: article.helpdesk_approval.approver_mappings.first.id)
    end
  end

  def test_approved_notifications
    article = get_approved_article(Account.current.language_object, @requester)
    ::Solution::ApprovalNotificationWorker.any_instance.expects(:push_data_to_service).once
    ::SolutionApprovalMailer.expects(:notify_approval).once
    Sidekiq::Testing.inline! do
      ::Solution::ApprovalNotificationWorker.perform_async(id: article.helpdesk_approval.approver_mappings.first.id)
    end
  end

  def test_worker_with_exception
    article = get_approved_article
    ::Solution::ApprovalNotificationWorker.any_instance.stubs(:push_data_to_service).raises(StandardError)
    assert_nothing_raised do
      Sidekiq::Testing.inline! do
        ::Solution::ApprovalNotificationWorker.perform_async(id: article.helpdesk_approval.approver_mappings.first.id)
      end
    end
  end
end
