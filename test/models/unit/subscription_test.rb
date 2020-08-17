require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'subscription_test_helper.rb')
['social_tickets_creation_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class SubscriptionTest < ActiveSupport::TestCase
  include AccountTestHelper
  include SocialTicketsCreationHelper
  include SubscriptionTestHelper

  def test_update_should_not_change_onboarding_state_for_active_accounts
    create_new_account('test1234', 'test1234@freshdesk.com')
    update_currency
    agent = @account.agents.first.user
    User.stubs(:current).returns(agent)
    Subscription.any_instance.stubs(:state).returns('active')
    Subscription.any_instance.stubs(:freshdesk_freshsales_bundle_enabled?).returns(false)
    Subscription.any_instance.stubs(:reseller_paid_account?).returns(false)
    subscription = @account.subscription
    @account.set_account_onboarding_pending
    assert_equal @account.onboarding_pending?, true
    subscription.plan = SubscriptionPlan.current.last
    subscription.save
    assert_equal @account.onboarding_pending?, true
  ensure
    Subscription.any_instance.unstub(:state)
    User.unstub(:current)
    Subscription.any_instance.unstub(:freshdesk_freshsales_bundle_enabled?)
    Subscription.any_instance.unstub(:reseller_paid_account?)
    @account.destroy
  end

  def test_update_changes_onboarding_state
    create_new_account('test1234', 'test1234@freshdesk.com')
    update_currency
    agent = @account.agents.first.user
    User.stubs(:current).returns(agent)
    Subscription.any_instance.stubs(:freshdesk_freshsales_bundle_enabled?).returns(false)
    Subscription.any_instance.stubs(:reseller_paid_account?).returns(false)
    subscription = @account.subscription
    @account.set_account_onboarding_pending
    assert_equal @account.onboarding_pending?, true
    subscription.plan = SubscriptionPlan.current.last
    subscription.state = 'active'
    subscription.save
    assert_equal @account.onboarding_pending?, false
  ensure
    User.unstub(:current)
    Subscription.any_instance.unstub(:freshdesk_freshsales_bundle_enabled?)
    Subscription.any_instance.unstub(:reseller_paid_account?)
    @account.destroy
  end

  def test_ticket_creation_on_omniplan_change
    create_new_account('test1234', 'test1234@freshdesk.com')
    update_currency
    agent = @account.agents.first.user
    User.stubs(:current).returns(agent)
    Subscription.any_instance.stubs(:freshdesk_freshsales_bundle_enabled?).returns(false)
    Subscription.any_instance.stubs(:reseller_paid_account?).returns(false)
    ProductFeedbackWorker.expects(:perform_async).once
    subscription = @account.subscription
    subscription.plan = SubscriptionPlan.current.find_by_name 'Garden Omni Jan 19'
    subscription.state = 'active'
    subscription.save
  ensure
    User.unstub(:current)
    Subscription.any_instance.unstub(:freshdesk_freshsales_bundle_enabled?)
    Subscription.any_instance.unstub(:reseller_paid_account?)
    @account.destroy
  end

  def test_ticket_creation_not_triggered_on_non_omniplan_change
    create_new_account('test1234', 'test1234@freshdesk.com')
    update_currency
    agent = @account.agents.first.user
    User.stubs(:current).returns(agent)
    Subscription.any_instance.stubs(:freshdesk_freshsales_bundle_enabled?).returns(false)
    Subscription.any_instance.stubs(:reseller_paid_account?).returns(false)
    ProductFeedbackWorker.expects(:perform_async).never
    subscription = @account.subscription
    subscription.plan = SubscriptionPlan.current.find_by_name 'Garden Jan 19'
    subscription.state = 'active'
    subscription.save
  ensure
    User.unstub(:current)
    Subscription.any_instance.unstub(:freshdesk_freshsales_bundle_enabled?)
    Subscription.any_instance.unstub(:reseller_paid_account?)
    @account.destroy
  end

  def test_omni_channel_ticket_params_method
    account = Account.first.make_current
    subscription = account.subscription
    description = subscription.omni_channel_ticket_params(account, subscription, nil)[:description]
    assert_equal description, "Customer has switched to / purchased an Omni-channel Freshdesk plan. <br>     <b>Account ID</b> : #{account.id}<br><b>Domain</b> : #{account.full_domain}<br><b>Current plan</b>     : #{subscription.plan_name}<br><b>Currency</b> : #{account.subscription.currency.name}<br><b>Previous plan</b> :     #{subscription.plan_name}<br><b>Contact</b> : <br>Ensure plan is set correctly in chat and caller."
  end

  def test_account_suspended_do_not_unsubscribe_twitter
    create_test_account
    create_social_streams
    subscription = @account.subscription
    @old_state = subscription.state
    subscription.state = 'suspended'
    subscription.save
    assert_equal @account.twitter_handles.present?, true
    assert_equal @account.twitter_streams.present?, true
    assert_equal @account.custom_twitter_streams.present?, true
  ensure
    subscription = @account.subscription
    subscription.state = @old_state
    subscription.save
  end

  def test_account_converted_to_omnibundle_if_changed_to_omniplan
    OmniChannelUpgrade::FreshcallerAccount.jobs.clear
    OmniChannelUpgrade::FreshchatAccount.jobs.clear
    create_new_account('test1234', 'test1234@freshdesk.com')
    update_currency
    result = ChargeBee::Result.new(stub_update_params(@account.id))
    agent = @account.agents.first.user
    subscription = @account.subscription
    bundle_create_stub_parms = bundle_create_stub
    User.stubs(:current).returns(agent)
    Freshid::V2::Models::Bundle.stubs(:create).returns(bundle_create_stub_parms)
    Freshid::V2::Models::Account.any_instance.stubs(:update).returns(Freshid::V2::ResponseHandler.new({}, 200, false))
    subscription.instance_variable_set(:@chargebee_update_response, result)
    Account.any_instance.stubs(:freshchat_account).returns(nil)
    Account.any_instance.stubs(:freshcaller_account).returns(nil)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(true)
    Account.any_instance.stubs(:account_additional_settings).returns(AccountAdditionalSettings.new(account_id: @account.id, email_cmds_delimeter: '@Simonsays', ticket_id_delimiter: '#', api_limit: 1000))
    Account.any_instance.stubs(:not_eligible_for_omni_conversion?).returns(false)
    subscription = @account.subscription
    subscription.account.launch(:explore_omnichannel_feature)
    subscription.plan = SubscriptionPlan.where(name: 'Forest Omni Jan 20').first
    subscription.state = 'active'
    subscription.save!
    @account.reload
    assert_equal @account.omni_bundle_id, bundle_create_stub_parms[:bundle][:id]
    assert_equal @account.omni_bundle_name, bundle_create_stub_parms[:bundle][:name]
    assert_equal OmniChannelUpgrade::FreshcallerAccount.jobs.size, 1
    assert_equal OmniChannelUpgrade::FreshchatAccount.jobs.size, 1
  ensure
    Account.any_instance.unstub(:launched?)
    User.unstub(:current)
    Freshid::V2::Models::Bundle.unstub(:create)
    Freshid::V2::Models::Account.any_instance.unstub(:update)
    Account.any_instance.unstub(:freshchat_account)
    Account.any_instance.unstub(:freshcaller_account)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:account_additional_settings)
    Account.any_instance.unstub(:not_eligible_for_omni_conversion?)
    @account.destroy
  end

  def test_account_not_converted_to_omnibundle_if_bundle_updation_has_error
    OmniChannelUpgrade::FreshcallerAccount.jobs.clear
    OmniChannelUpgrade::FreshchatAccount.jobs.clear
    @account = Account.first.make_current || create_test_account
    is_launched = @account.launched?(:explore_omnichannel_feature)
    @account.launch(:explore_omnichannel_feature) unless is_launched
    result = ChargeBee::Result.new(stub_update_params(@account.id))
    agent = @account.agents.first.user
    subscription = @account.subscription
    bundle_create_stub_parms = bundle_create_stub
    User.stubs(:current).returns(agent)
    Freshid::V2::Models::Bundle.stubs(:create).returns(bundle_create_stub_parms)
    Freshid::V2::Models::Account.any_instance.stubs(:update).returns(Freshid::V2::ResponseHandler.new({}, 400, true))
    subscription.instance_variable_set(:@chargebee_update_response, result)
    Account.any_instance.stubs(:freshchat_account).returns(nil)
    Account.any_instance.stubs(:freshcaller_account).returns(nil)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(true)
    Account.any_instance.stubs(:not_eligible_for_omni_conversion?).returns(false)
    Account.any_instance.stubs(:account_additional_settings).returns(AccountAdditionalSettings.new(account_id: @account.id, email_cmds_delimeter: '@Simonsays', ticket_id_delimiter: '#', api_limit: 1000))
    subscription = @account.subscription
    subscription.plan = SubscriptionPlan.where(name: 'Forest Omni Jan 20').first
    subscription.state = 'active'
    subscription.save
    @account.reload
    assert_nil @account.omni_bundle_id, bundle_create_stub_parms[:bundle][:id]
    assert_nil @account.omni_bundle_name, bundle_create_stub_parms[:bundle][:name]
    assert_equal OmniChannelUpgrade::FreshcallerAccount.jobs.size, 0
    assert_equal OmniChannelUpgrade::FreshchatAccount.jobs.size, 0
  ensure
    User.unstub(:current)
    Freshid::V2::Models::Bundle.unstub(:create)
    Freshid::V2::Models::Account.any_instance.unstub(:update)
    Account.any_instance.unstub(:freshchat_account)
    Account.any_instance.unstub(:freshcaller_account)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    Account.any_instance.unstub(:account_additional_settings)
    Account.any_instance.unstub(:not_eligible_for_omni_conversion?)
    @account.rollback(:explore_omnichannel_feature) unless is_launched
  end

  def create_social_streams
    twitter_handle = FactoryGirl.build(:seed_twitter_handle)
    twitter_handle.account_id = @account.id
    twitter_handle.save!
    custom_stream = FactoryGirl.build(:seed_twitter_stream)
    custom_stream.account_id = @account.id
    custom_stream.social_id = nil
    custom_stream.save!
    custom_stream.populate_accessible(Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all])
  end

  def test_check_fd_fs_banner_redis_expiry
    Subscription.any_instance.stubs(:trial?).returns(true)
    Subscription.any_instance.stubs(:freshdesk_freshsales_bundle_enabled?).returns(true)
    subscription = @account.subscription
    previous_state = subscription.state
    subscription.state = 'active'
    subscription.save
    redis_expiry = get_others_redis_expiry(@account.account_activated_within_last_week_key)
    assert_operator 1_814_000, :<=, redis_expiry
  ensure
    subscription.state = previous_state
    subscription.save
    Subscription.any_instance.unstub(:freshdesk_freshsales_bundle_enabled?)
    Subscription.any_instance.unstub(:trial?)
  end

  def test_switch_to_annual_notification_reminder
    ::Scheduler::PostMessage.jobs.clear
    ::Scheduler::CancelMessage.jobs.clear
    Subscription.any_instance.stubs(:freshdesk_freshsales_bundle_enabled?).returns(false)
    Subscription.any_instance.stubs(:reseller_paid_account?).returns(false)
    Subscription.any_instance.stubs(:offline_subscription?).returns(false)
    Subscription.any_instance.stubs(:amount).returns(50)
    subscription = @account.subscription
    subscription.additional_info[:annual_notification_triggered] = false
    subscription.save
    previous_state = subscription.state
    previous_renewal_period = subscription.renewal_period
    subscription.state = 'active'
    subscription.renewal_period = 1
    subscription.save
    assert_equal 3, ::Scheduler::PostMessage.jobs.size
    assert_equal 0, ::Scheduler::CancelMessage.jobs.size
  ensure
    subscription.additional_info[:annual_notification_triggered] = false
    subscription.state = previous_state
    subscription.renewal_period = previous_renewal_period
    subscription.save
    Subscription.any_instance.unstub(:freshdesk_freshsales_bundle_enabled?)
    Subscription.any_instance.unstub(:reseller_paid_account?)
    Subscription.any_instance.unstub(:offline_subscription?)
    Subscription.any_instance.unstub(:amount)
    ::Scheduler::PostMessage.jobs.clear
    ::Scheduler::CancelMessage.jobs.clear
  end

  def test_switch_to_annual_notification_reminder_annual_subscription
    ::Scheduler::PostMessage.jobs.clear
    ::Scheduler::CancelMessage.jobs.clear
    Subscription.any_instance.stubs(:freshdesk_freshsales_bundle_enabled?).returns(false)
    Subscription.any_instance.stubs(:reseller_paid_account?).returns(false)
    Subscription.any_instance.stubs(:offline_subscription?).returns(false)
    Subscription.any_instance.stubs(:amount).returns(50)
    subscription = @account.subscription
    previous_state = subscription.state
    previous_renewal_period = subscription.renewal_period
    subscription.state = 'active'
    subscription.renewal_period = 12
    subscription.save
    assert_equal 0, ::Scheduler::PostMessage.jobs.size
    assert_equal 0, ::Scheduler::CancelMessage.jobs.size
  ensure
    subscription.state = previous_state
    subscription.renewal_period = previous_renewal_period
    subscription.save
    Subscription.any_instance.unstub(:freshdesk_freshsales_bundle_enabled?)
    Subscription.any_instance.unstub(:reseller_paid_account?)
    Subscription.any_instance.unstub(:offline_subscription?)
    Subscription.any_instance.unstub(:amount)
    ::Scheduler::PostMessage.jobs.clear
    ::Scheduler::CancelMessage.jobs.clear
  end

  def test_switch_to_annual_notification_reminder_trial_state
    ::Scheduler::PostMessage.jobs.clear
    ::Scheduler::CancelMessage.jobs.clear
    Subscription.any_instance.stubs(:freshdesk_freshsales_bundle_enabled?).returns(false)
    Subscription.any_instance.stubs(:reseller_paid_account?).returns(false)
    Subscription.any_instance.stubs(:offline_subscription?).returns(false)
    Subscription.any_instance.stubs(:amount).returns(50)
    subscription = @account.subscription
    previous_state = subscription.state
    previous_renewal_period = subscription.renewal_period
    subscription.state = 'trial'
    subscription.renewal_period = 1
    subscription.save
    assert_equal 0, ::Scheduler::PostMessage.jobs.size
    assert_equal 0, ::Scheduler::CancelMessage.jobs.size
  ensure
    subscription.state = previous_state
    subscription.renewal_period = previous_renewal_period
    subscription.save
    Subscription.any_instance.unstub(:freshdesk_freshsales_bundle_enabled?)
    Subscription.any_instance.unstub(:reseller_paid_account?)
    Subscription.any_instance.unstub(:offline_subscription?)
    Subscription.any_instance.unstub(:amount)
    ::Scheduler::PostMessage.jobs.clear
    ::Scheduler::CancelMessage.jobs.clear
  end

  def test_switch_to_annual_notification_reminder_for_reseller
    ::Scheduler::PostMessage.jobs.clear
    ::Scheduler::CancelMessage.jobs.clear
    Subscription.any_instance.stubs(:freshdesk_freshsales_bundle_enabled?).returns(false)
    Subscription.any_instance.stubs(:reseller_paid_account?).returns(true)
    Subscription.any_instance.stubs(:offline_subscription?).returns(false)
    Subscription.any_instance.stubs(:amount).returns(50)
    subscription = @account.subscription
    previous_state = subscription.state
    previous_renewal_period = subscription.renewal_period
    subscription.state = 'active'
    subscription.renewal_period = 1
    subscription.save
    assert_equal 0, ::Scheduler::PostMessage.jobs.size
    assert_equal 0, ::Scheduler::CancelMessage.jobs.size
  ensure
    subscription.state = previous_state
    subscription.renewal_period = previous_renewal_period
    subscription.save
    Subscription.any_instance.unstub(:freshdesk_freshsales_bundle_enabled?)
    Subscription.any_instance.unstub(:reseller_paid_account?)
    Subscription.any_instance.unstub(:offline_subscription?)
    Subscription.any_instance.unstub(:amount)
    ::Scheduler::PostMessage.jobs.clear
    ::Scheduler::CancelMessage.jobs.clear
  end

  def test_switch_to_annual_notification_reminder_offline_subscription
    ::Scheduler::PostMessage.jobs.clear
    ::Scheduler::CancelMessage.jobs.clear
    Subscription.any_instance.stubs(:freshdesk_freshsales_bundle_enabled?).returns(false)
    Subscription.any_instance.stubs(:reseller_paid_account?).returns(false)
    Subscription.any_instance.stubs(:offline_subscription?).returns(true)
    Subscription.any_instance.stubs(:amount).returns(50)
    subscription = @account.subscription
    previous_state = subscription.state
    previous_renewal_period = subscription.renewal_period
    subscription.state = 'active'
    subscription.renewal_period = 1
    subscription.save
    assert_equal 0, ::Scheduler::PostMessage.jobs.size
    assert_equal 0, ::Scheduler::CancelMessage.jobs.size
  ensure
    subscription.state = previous_state
    subscription.renewal_period = previous_renewal_period
    subscription.save
    Subscription.any_instance.unstub(:freshdesk_freshsales_bundle_enabled?)
    Subscription.any_instance.unstub(:reseller_paid_account?)
    Subscription.any_instance.unstub(:offline_subscription?)
    Subscription.any_instance.unstub(:amount)
    ::Scheduler::PostMessage.jobs.clear
    ::Scheduler::CancelMessage.jobs.clear
  end

  def test_switch_to_annual_notification_reminder_sprout_plan
    ::Scheduler::PostMessage.jobs.clear
    ::Scheduler::CancelMessage.jobs.clear
    Subscription.any_instance.stubs(:freshdesk_freshsales_bundle_enabled?).returns(false)
    Subscription.any_instance.stubs(:amount).returns(0)
    Subscription.any_instance.stubs(:reseller_paid_account?).returns(false)
    Subscription.any_instance.stubs(:offline_subscription?).returns(false)
    subscription = @account.subscription
    previous_state = subscription.state
    previous_renewal_period = subscription.renewal_period
    subscription.state = 'active'
    subscription.renewal_period = 1
    subscription.save
    assert_equal 0, ::Scheduler::PostMessage.jobs.size
    assert_equal 0, ::Scheduler::CancelMessage.jobs.size
  ensure
    subscription.state = previous_state
    subscription.renewal_period = previous_renewal_period
    subscription.save
    Subscription.any_instance.unstub(:freshdesk_freshsales_bundle_enabled?)
    Subscription.any_instance.unstub(:reseller_paid_account?)
    Subscription.any_instance.unstub(:offline_subscription?)
    Subscription.any_instance.unstub(:amount)
    ::Scheduler::PostMessage.jobs.clear
    ::Scheduler::CancelMessage.jobs.clear
  end

  def test_switch_to_annual_notification_reminder_with_payments
    ::Scheduler::PostMessage.jobs.clear
    ::Scheduler::CancelMessage.jobs.clear
    Subscription.any_instance.stubs(:freshdesk_freshsales_bundle_enabled?).returns(false)
    Subscription.any_instance.stubs(:subscription_payments).returns(Array(SubscriptionPayment.new(meta_info: { renewal_period: 1 })))
    Subscription.any_instance.stubs(:amount).returns(50)
    Subscription.any_instance.stubs(:reseller_paid_account?).returns(false)
    Subscription.any_instance.stubs(:offline_subscription?).returns(false)
    subscription = @account.subscription
    previous_state = subscription.state
    previous_renewal_period = subscription.renewal_period
    subscription.state = 'active'
    subscription.renewal_period = 1
    subscription.save
    assert_equal 0, ::Scheduler::PostMessage.jobs.size
    assert_equal 0, ::Scheduler::CancelMessage.jobs.size
  ensure
    subscription.state = previous_state
    subscription.renewal_period = previous_renewal_period
    subscription.save
    Subscription.any_instance.unstub(:freshdesk_freshsales_bundle_enabled?)
    Subscription.any_instance.unstub(:reseller_paid_account?)
    Subscription.any_instance.unstub(:offline_subscription?)
    Subscription.any_instance.unstub(:amount)
    Subscription.any_instance.unstub(:subscription_payments)
    ::Scheduler::PostMessage.jobs.clear
    ::Scheduler::CancelMessage.jobs.clear
  end

  private

    def bundle_create_stub
      {
        bundle: {
          id: Faker::Number.number(5),
          name: Faker::Lorem.word
        }
      }
    end
end
