require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

Sidekiq::Testing.fake!

class AttachmentUserDraftCleanupTest < ActionView::TestCase
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

  def test_attachment_user_draft_cleanup
    Helpdesk::MultiFileAttachment::AttachmentCleanup.any_instance.expects(:cleanup).once
    CronWebhooks::AttachmentUserDraftCleanup.new.perform(task_name: 'attachment_cleanup_user_draft_cleanup')
  end
end
