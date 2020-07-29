require_relative '../../unit_test_helper.rb'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class OmniSubscriptionUpdateMethodsTest < ActionView::TestCase
  include ::AccountTestHelper
  include Billing::OmniSubscriptionUpdateMethods

  def setup
    super
    @account = create_new_account
    Account.any_instance.stubs(:current).returns(@account)
  end

  def teardown
    Account.any_instance.stubs(:current)
    super
  end

  def test_invoice_details_included_when_event_has_invoice_payload
    chargebee_event = construct_test_subscription_params_with_invoice
    
    payload = construct_payload(chargebee_event)
    
    assert_equal true, payload[:payload][:event_payload][:content].key?(:invoice)
    assert_equal expected_invoice_payload, payload[:payload][:event_payload][:content][:invoice]
  end

  def test_invoice_details_not_included_when_event_has_no_invoice_payload
    chargebee_event = construct_test_subscription_params_without_invoice
    
    payload = construct_payload(chargebee_event)
    
    assert_equal false, payload[:payload][:event_payload][:content].key?(:invoice)
  end

  private

    def construct_test_subscription_params_with_invoice
      {
        id: 'ev_AzyyIgRx6WeSD1eSo',
        occurred_at: 15,
        source: 'scheduled_job',
        object: 'event',
        api_version: 'v1',
        content: {
          subscription: {
            id: '431171',
            plan_id: 'forest_jan_20_annual',
            plan_quantity: 23,
            status: 'active',
            trial_start: 1_477_316_976,
            trial_end: 1_477_339_021,
            current_term_start: 1_587_754_631,
            current_term_end: 1_590_346_631,
            created_at: 1_471_884_655,
            started_at: 1_471_884_655,
            activated_at: 1_527_626_432,
            has_scheduled_changes: false,
            object: 'subscription',
            coupon: 'IPWHITELISTINGFREEFOREVERQUANTITYTEST',
            addons: [],
            coupons: [],
            due_invoices_count: 0
          },
          customer: {
            id: '431171',
            first_name: 'Noelty',
            last_name: 'Berry',
            email: 'test@random.com',
            company: 'The Random Group',
            auto_collection: 'on',
            allow_direct_debit: false,
            created_at: 1_471_884_655,
            taxability: 'taxable',
            object: 'customer',
            billing_address: {
              first_name: 'Willie',
              last_name: 'Beiber',
              line1: '3155 Random street',
              city: 'Troy',
              state_code: '[FILTERED]',
              state: 'Michigan',
              country: 'US',
              zip: '48084',
              object: 'billing_address'
            },
            card_status: 'valid',
            payment_method: {
              object: 'payment_method',
              type: 'card',
              reference_id: 'cus_Cs6OYVNQum26OJ/card_1Ei3m4FIIj5rWBMApOoX8k6WXX',
              gateway: 'stripe',
              status: 'valid'
            },
            account_credits: 0,
            refundable_credits: 0,
            excess_payments: 0,
            cf_account_domain: 'ustest.freshdesk.com',
            meta_data: {
              customer_key: 'fdesk.4311711'
            }
          },
          card: {
            status: 'valid',
            reference_id: 'cus_Cs6OYVNQum26OJ/card_1Ei3m4FIIj5rWBMApOoX8k6Wxx',
            gateway: 'stripe',
            first_name: 'Noelty',
            last_name: 'J  Berry',
            iin: '******',
            last4: '2406',
            card_type: 'visa',
            expiry_month: 1,
            expiry_year: 2024,
            customer_id: '431171'
          },
          invoice: {
            id: 'FD1026207',
            sub_total: 57_502,
            start_date: 1_585_076_231,
            customer_id: '431171',
            subscription_id: '431171',
            recurring: true,
            status: 'paid',
            price_type: 'tax_exclusive',
            end_date: 1_587_754_631,
            amount: 57_500,
            amount_paid: 57_500,
            amount_adjusted: 0,
            credits_applied: 0,
            amount_due: 0,
            paid_on: 1_587_754_636,
            object: 'invoice',
            first_invoice: false,
            currency_code: 'USD',
            tax: 0,
            line_items: [
              {
                date_from: 1_347_114_478,
                entity_type: 'plan',
                type: 'charge',
                date_to: 1_349_706_478,
                unit_amount: 900,
                quantity: 1,
                is_taxed: false,
                tax: 0,
                object: 'line_item',
                amount: 900,
                description: 'Basic',
                entity_id: 'basic'
              }
            ],
            discounts: [],
            linked_transactions: [],
            linked_orders: nil,
            billing_address: {
              first_name: 'Willie',
              last_name: 'J  Berry',
              object: 'billing_address'
            }
          }
        },
        event_type: 'subscription_changed',
        webhook_status: 'scheduled',
        webhooks: [
          {
            id: 'wh_56',
            webhook_status: 'scheduled',
            object: 'webhook'
          }
        ],
        digest: '1be618a2d095a0b718415c231c554c7c',
        name_prefix: 'fdadmin_',
        path_prefix: nil,
        action: 'trigger',
        controller: 'fdadmin/billing'
      }
    end

    def construct_test_subscription_params_without_invoice
      payload = construct_test_subscription_params_with_invoice
      payload[:content].delete(:invoice)
      payload
    end

    def expected_invoice_payload
      {
        id: 'FD1026207',
        total: 57_500,
        amount_adjusted: 0,
        amount_due: 0,
        amount_paid: 57_500,
        currency_code: 'USD',
        customer_id: '431171',
        date: 1_587_754_631,
        object: 'invoice',
        price_type: 'tax_exclusive',
        recurring: true,
        status: 'paid',
        sub_total: 57_502,
        subscription_id: '431171',
        tax: 0,
        line_items: [
          {
            date_from: 1_347_114_478,
            entity_type: 'plan',
            type: 'charge',
            date_to: 1_349_706_478,
            unit_amount: 900,
            quantity: 1,
            is_taxed: false,
            tax_amount: 0,
            object: 'line_item',
            amount: 900,
            description: 'Basic',
            entity_id: 'basic'
          }
        ]
      }
    end
end
