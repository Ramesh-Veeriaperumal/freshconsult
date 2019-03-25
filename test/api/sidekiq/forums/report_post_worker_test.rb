require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'forums_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

class ReportPostWorkerTest < ActionView::TestCase
  include CoreForumsTestHelper
  include CoreUsersTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @new_user = add_new_user(@account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_report_post_worker_with_submit_ham
    new_post = quick_create_post
    params = request_params(new_post, Post::REPORT[:ham])
    params[:klass_name] = 'ForumSpam'
    ForumSpam.stubs(:find_post).with(new_post.id).returns(new_post)
    Akismetor.expects(:safe_send).with(Post::REPORT[:ham] ? :submit_ham : :submit_spam, akismet_params(new_post)).once
    Community::ReportPostWorker.new.perform(params)
  ensure
    ForumSpam.unstub(:find_post)
  end

  def test_report_post_worker_with_submit_spam
    new_post = quick_create_post
    Akismetor.expects(:safe_send).with(Post::REPORT[:spam] ? :submit_ham : :submit_spam, akismet_params(new_post)).once
    Community::ReportPostWorker.new.perform(request_params(new_post, Post::REPORT[:spam]))
  end

  def test_account_record_not_found_exception
    new_post = quick_create_post
    Account.any_instance.stubs(:blank?).returns(true)
    Rails.logger.expects(:error).with("ReportPostWorker - #{Account.current} - #{ActiveRecord::RecordNotFound}").once
    Community::ReportPostWorker.new.perform(request_params(new_post, Post::REPORT[:ham]))
  ensure
    Account.any_instance.unstub(:blank?)
  end

  private

    def quick_create_post
      new_category = create_test_category
      new_forum = create_test_forum(new_category)
      new_topic = create_test_topic(new_forum, @new_user)
      new_post = create_test_post(new_topic, true, @new_user)
    end

    def request_params(post, type)
      {
        id: post.id,
        account_id: post.account_id,
        klass_name: post.class.name,
        report_type: type
      }
    end

    def akismet_params(post)
      {
        key: AkismetConfig::KEY,
        comment_type: 'forum-post',
        blog: post.account.full_url,
        comment_author: post.user.name,
        comment_author_email: post.user.email,
        comment_content: post.body,
        is_test: 1
      }
    end
end
