require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

Sidekiq::Testing.fake!

class SpamDigestMailerTest < ActionView::TestCase
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

  def with_necessary_stubs
    olz_time_zone = @account.time_zone
    @account.time_zone = 'Casablanca'
    @account.save
    Time.zone.stubs(:now).returns(Time.new(1, 1, 1, 16))
    Account.stubs(:forum_moderators).returns([ForumModerator.new])
    ActiveRecord::Base.stubs(:supports_sharding?).returns(false)
    Account.stubs(:active_accounts).returns(Account)
    Account.any_instance.stubs(:features_included?).with(:forums).returns(true)

    yield

    ForumModerator.any_instance.unstub(:email)
    Account.any_instance.unstub(:features_included?)
    Account.unstub(:active_accounts)
    Account.unstub(:forum_moderators)
    ActiveRecord::Base.unstub(:supports_sharding?)
    Time.zone.unstub(:now)
    @account.time_zone = olz_time_zone
    @account.save
  end

  def test_enqueue_spam_digest_mailer_jobs_without_forum_moderators
    with_necessary_stubs do
      Community::DispatchSpamDigest.drain
      ForumModerator.any_instance.stubs(:email).returns(nil)
      CronWebhooks::SpamDigestMailer.new.perform(task_name: 'spam_digest_mailer_queue')
      assert_equal 0, Community::DispatchSpamDigest.jobs.size
    end
  end
end
