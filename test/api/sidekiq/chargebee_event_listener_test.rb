require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
require 'webmock/minitest'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

Sidekiq::Testing.fake!

class ChargebeeEventListenerTest < ActionView::TestCase
  include AccountTestHelper

  ADDON_DATA = [{ id: 'marketplaceapp__8493_44556', quantity: 1, object: 'addon' }].freeze

  def setup
    super
    @account = Account.current || create_account_if_not_exists
    Subscription.any_instance.stubs(:agent_limit).returns(1)
  end

  def teardown
    Subscription.any_instance.unstub(:agent_limit)
    @account.subscription.state = 'trial'
    @account.subscription.save
    super
  end

  def create_account_if_not_exists
    user = create_test_account
    user.account
  end

  def test_subscription_renewed_event_to_raise_exception_on_addon_changes
    Subscription.any_instance.stubs(:offline_subscription?).returns(false)
    Subscription.any_instance.stubs(:reseller_paid_account?).returns(false)
    assert_raise RuntimeError do
      @account.subscription.update_attributes(additional_info: { field_agent_limit: 10 })
      addons = Subscription::Addon.where(name: Subscription::Addon::FSM_ADDON)
      addon_id = addons.first.billing_addon_id
      @account.subscription.addons = addons
      @account.subscription.save!

      args = {
        acc_id: @account.id,
        plan_id: Billing::Subscription.helpkit_plan.key(@account.plan_name.to_s),
        plan_quantity: @account.subscription.agent_limit,
        addons: [{ id: addon_id.to_s, quantity: 1, object: 'addon' }]
      }
      event_data = subscription_renewed_event_data(args)
      Billing::ChargebeeEventListener.new.perform(event_data)
    end
  ensure
    Subscription.any_instance.unstub(:offline_subscription?)
    Subscription.any_instance.unstub(:reseller_paid_account?)
  end

  def test_subscription_renewed_event_to_raise_exception_on_plan_change
    assert_raise RuntimeError do
      args = {
        acc_id: @account.id,
        plan_id: (Billing::Subscription.helpkit_plan.keys - [Billing::Subscription.helpkit_plan.key(@account.plan_name.to_s)]).first,
        plan_quantity: @account.subscription.agent_limit,
        addons: ADDON_DATA
      }
      event_data = subscription_renewed_event_data(args)
      Billing::ChargebeeEventListener.new.perform(event_data)
    end
  end

  def test_subscription_renewed_event_to_raise_exception_on_plan_quantity_change
    assert_raise RuntimeError do
      args = {
        acc_id: @account.id,
        plan_id: Billing::Subscription.helpkit_plan.key(@account.plan_name.to_s),
        plan_quantity: @account.subscription.agent_limit + 5,
        addons: ADDON_DATA
      }
      event_data = subscription_renewed_event_data(args)
      Billing::ChargebeeEventListener.new.perform(event_data)
    end
  end

  def test_subscription_renewed_event_for_successful_update
    assert_nothing_raised do
      @account.subscription.next_renewal_at = Time.zone.now
      @account.subscription.save!
      next_renewal_date = (Time.zone.now + 7.months).to_i
      args = {
        acc_id: @account.id,
        plan_id: Billing::Subscription.helpkit_plan.key(@account.plan_name.to_s),
        plan_quantity: @account.subscription.agent_limit,
        addons: ADDON_DATA,
        next_renewal: next_renewal_date
      }
      event_data = subscription_renewed_event_data(args)
      Billing::ChargebeeEventListener.new.perform(event_data)
      assert_equal @account.reload.subscription.next_renewal_at.to_i, next_renewal_date
    end
  end

  def subscription_renewed_event_data(args)
    next_renewal = args[:next_renewal] || (Time.zone.now + 1.month).to_i
    auto_collection = args[:auto_collection] || 'off'
    status = args[:status] || 'active'
    payload = { account_id: args[:acc_id], event_type: 'subscription_renewed', content: { subscription: { id: '1171555', plan_id: args[:plan_id], plan_quantity: args[:plan_quantity], status: status, trial_start: 1_565_699_778, trial_end: 1_567_853_255, current_term_end: next_renewal, has_scheduled_changes: false, object: 'subscription', due_invoices_count: 1, due_since: 1_581_076_055, total_dues: 68_000 }, customer: { id: '1', first_name: 'Youma', last_name: 'Fall' }, card: { first_name: 'Youma', last_name: 'Dieng Fall', iin: '******', object: 'card', masked_number: '************2339', customer_id: '1171555' }, invoice: { id: 'FD978228', sub_total: 7_682_736_787, start_date: 1_578_397_655, customer_id: '1171555', subscription_id: '1171555', price_type: 'tax_exclusive', end_date: 1_581_076_055, amount: 68_000, amount_due: 68_000, dunning_status: 'in_progress', object: 'invoice', first_invoice: false } }, format: 'json', controller: 'billing/billing', action: 'trigger', billing: { event_type: 'subscription_renewed', content: { subscription: { id: '1171555', plan_id: 'estate_omni_jan_19_monthly', plan_quantity: 8, status: status, object: 'subscription', due_invoices_count: 1, due_since: 1_581_076_055, total_dues: 68_000 }, customer: { id: '1', first_name: 'Youma', last_name: 'Fall', email: 'fall@paydunya.com', company: 'PayDunya', auto_collection: auto_collection }, invoice: { id: 'FD978228', sub_total: 6_887_278, start_date: 1_578_397_655 } } } }
    payload[:content][:subscription][:addons] = args[:addons] if args[:addons].present?
    payload
  end
end
