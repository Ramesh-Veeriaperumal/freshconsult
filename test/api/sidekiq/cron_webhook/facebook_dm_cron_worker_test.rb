require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../test_transactions_fixtures_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'groups_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'facebook_test_helper.rb')
class FacebookDMCronWorker < ActionView::TestCase
  include AccountTestHelper
  include GroupsTestHelper
  include FacebookTestHelper
  def teardown
    Social::FacebookPage.any_instance.stubs(:unsubscribe_realtime).returns(true)
    Subscription.any_instance.unstub(:switch_annual_notification_eligible?)
    super
    @account.facebook_pages.destroy_all
    @account.facebook_streams.destroy_all
    @account.tickets.where(source: Helpdesk::Source::FACEBOOK).destroy_all
    Account.unstub(:current)
  ensure
    Social::FacebookPage.any_instance.unstub(:unsubscribe_realtime)
    HttpRequestProxy.any_instance.unstub(:fetch_using_req_params)
  end

  def setup
    Account.stubs(:current).returns(Account.first)
    Subscription.any_instance.stubs(:switch_annual_notification_eligible?).returns(false)
    HttpRequestProxy.any_instance.stubs(:fetch_using_req_params).returns(status: 200, text: '{"pages": [{"id": 568, "freshdeskAccountId": "1", "facebookPageId": "532218423476440"}], "meta": {"count": 1}}')
    @account = Account.current
    @fb_page = create_test_facebook_page(@account)
    @user_id = rand(10**10)
    @user = @account.nil? ? create_test_account : add_new_user(@account)
    @user.make_current
  end

  def test_no_exception
    assert_nothing_raised do
      CronWebhooks::FacebookDm.new.perform(type: 'trial', task_name: 'scheduler_facebook')
      CronWebhooks::FacebookDm.new.perform(type: 'paid', task_name: 'scheduler_facebook')
    end
  end

  def test_trial_facebook_worker
    Social::TrialFacebookWorker.drain
    old_state = @account.subscription.state
    change_account_state(Subscription::TRIAL, @account) unless @account.subscription.trial?
    CronWebhooks::FacebookDm.new.perform(type: 'trial', task_name: 'scheduler_facebook')
    assert_equal 1, Social::TrialFacebookWorker.jobs.size, 'Expected trial worker count doesnt match'
  ensure
    change_account_state(old_state, @account)
  end

  def test_paid_facebook_worker
    Social::FacebookWorker.drain
    old_state = @account.subscription.state
    change_account_state(Subscription::ACTIVE, @account) unless @account.subscription.active?
    CronWebhooks::FacebookDm.new.perform(type: 'paid', task_name: 'scheduler_facebook')
    assert_equal 1, Social::FacebookWorker.jobs.size, 'Expected paid worker count doesnt match'
  ensure
    change_account_state(old_state, @account)
  end

  def test_premium_facebook_worker
    Social::PremiumFacebookWorker.drain
    old_state = @account.subscription.state
    CronWebhooks::FacebookDm.any_instance.stubs(:premium_facebook_accounts).returns([@account.id])
    change_account_state(Subscription::ACTIVE, @account) unless @account.subscription.active?
    CronWebhooks::FacebookDm.new.perform(type: 'paid', task_name: 'scheduler_facebook')
    assert_equal 2, Social::PremiumFacebookWorker.jobs.size, 'Expected paid worker count doesnt match'
  ensure
    change_account_state(old_state, @account)
    CronWebhooks::FacebookDm.any_instance.unstub(:premium_facebook_accounts)
  end
end
