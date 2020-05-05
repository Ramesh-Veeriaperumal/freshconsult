require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
require 'webmock/minitest'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'freshchat_account_test_helper.rb')

Sidekiq::Testing.fake!

class FreshchatSubscriptionUpdateTest < ActionView::TestCase
  include AccountTestHelper
  include FreshchatAccountTestHelper

  def setup
    super
    @account = Account.current || create_account_if_not_exists
  end

  def teardown
    super
  end

  def create_account_if_not_exists
    user = create_test_account
    user.account
  end

  def test_omni_subscription_update_successful_update
    stub_freshchat_omni_request(200, 'OK', { transactionId: 'S311111111', message: "success" })
    create_freshchat_account(Account.current)
    assert_nothing_raised do
      Billing::FreshchatSubscriptionUpdate.new.perform(construct_test_subscription_params)
    end
  ensure
    unstub_freshchat_omni_request
  end

  def stub_freshchat_omni_request(status = 200, message = 'OK', body = {})
    Account.stubs(:current).returns(@account)
    @resp = stub_request(:post, FreshchatSubscriptionConfig['subscription_host']).to_return(body: body.to_json,
        status: status,
        headers: { 'Content-Type' => 'application/json' })
  end

  def unstub_freshchat_omni_request
    Account.unstub(:current)
    remove_request_stub(@resp)
  end

  private

    def construct_test_subscription_params
      {
          :id=>"ev_AzyyIgRx6WeSD1eSo", :occurred_at=>1587754637,:source=>"scheduled_job",
          :object=>"event", :api_version=>"v1",
          :content=>{:subscription=>{
              :id=>"431171", :plan_id=>"forest_jan_20_annual", :plan_quantity=>23, :status=>"active",
              :trial_start=>1477316976, :trial_end=>1477339021, :current_term_start=>1587754631,
              :current_term_end=>1590346631, :created_at=>1471884655, :started_at=>1471884655,
              :activated_at=>1527626432, :has_scheduled_changes=>false, :object=>"subscription",
              :coupon=>"IPWHITELISTINGFREEFOREVERQUANTITYTEST",
              :addons=>[{"id"=>"whitelisted_ips", "quantity"=>23, "object"=>"addon"}],
              :coupons=>[{"coupon_id"=>"IPWHITELISTINGFREEFOREVERQUANTITYTEST", "applied_count"=>41, "object"=>"coupon"},
                  {"coupon_id"=>"13.79%ONGARDENMONTHLYRANDOM", "applied_count"=>40, "object"=>"coupon"}],
              :due_invoices_count=>0
          }, :customer=>{
              :id=>"431171", :first_name=>"Noelty", :last_name=>"Berry", :email=>"test@random.com",
              :company=>"The Random Group", :auto_collection=>"on", :allow_direct_debit=>false, :created_at=>1471884655,
              :taxability=>"taxable", :object=>"customer",
              :billing_address=>{:first_name=>"Willie", :last_name=>"Beiber", :line1=>"3155 Random street",
                  :city=>"Troy", :state_code=>"[FILTERED]", :state=>"Michigan", :country=>"US", :zip=>"48084", :object=>"billing_address"
              },
              :card_status=>"valid",
              :payment_method=>{
                  :object=>"payment_method", :type=>"card", :reference_id=>"cus_Cs6OYVNQum26OJ/card_1Ei3m4FIIj5rWBMApOoX8k6WXX",
                  :gateway=>"stripe", :status=>"valid"},
              :account_credits=>0, :refundable_credits=>0, :excess_payments=>0, :cf_account_domain=>"ustest.freshdesk.com",
              :meta_data=>{:customer_key=>"fdesk.4311711"}}, :card=>{:status=>"valid",
              :reference_id=>"cus_Cs6OYVNQum26OJ/card_1Ei3m4FIIj5rWBMApOoX8k6Wxx",
              :gateway=>"stripe", :first_name=>"Noelty", :last_name=>"J  Berry", :iin=>"******", :last4=>"2406",
              :card_type=>"visa", :expiry_month=>1, :expiry_year=>2024, :billing_addr1=>"3155 W Big Beaver Rd",
              :billing_addr2=>"Suite 216", :billing_city=>"Troy", :billing_state_code=>"110059", :billing_state=>"Michigan",
              :billing_country=>"US", :billing_zip=>"48084", :ip_address=>"38.30.0.66", :object=>"card",
              :masked_number=>"************2406", :customer_id=>"431171"},
              :invoice=>{:id=>"FD1026207", :sub_total=>57502, :start_date=>1585076231, :customer_id=>"431171",
                  :subscription_id=>"431171", :recurring=>true, :status=>"paid", :price_type=>"tax_exclusive",
                  :end_date=>1587754631, :amount=>57500, :amount_paid=>57500, :amount_adjusted=>0, :credits_applied=>0,
                  :amount_due=>0, :paid_on=>1587754636, :object=>"invoice", :first_invoice=>false, :currency_code=>"USD",
                  :tax=>0, :line_items=>[{"date_from"=>1587754631, "entity_type"=>"plan", "type"=>"charge", "date_to"=>1590346631,
                      "unit_amount"=>2900, "quantity"=>23, "amount"=>66700, "is_taxed"=>false, "tax"=>0, "object"=>"line_item",
                      "description"=>"[FILTERED]", "entity_id"=>"garden_monthly"},
                      {"date_from"=>1587754631, "entity_type"=>"addon", "type"=>"charge", "date_to"=>1590346631,
                          "unit_amount"=>1500, "quantity"=>23, "amount"=>34500, "is_taxed"=>false, "tax"=>0, "object"=>"line_item",
                          "description"=>"[FILTERED]", "entity_id"=>"whitelisted_ips"}],
                  :discounts=>[{"object"=>"discount", "description"=>"[FILTERED]", "type"=>"coupon", "amount"=>34500, "entity_id"=>"IPWHITELISTINGFREEFOREVERQUANTITYTEST"},
                      {"object"=>"discount", "description"=>"[FILTERED]", "type"=>"coupon", "amount"=>9198, "entity_id"=>"13.79%ONGARDENMONTHLYTEST"}],
                  :linked_transactions=>[{"txn_id"=>"txn_AzyyIgRx6WdvR1eSQ", "txn_type"=>"payment", "applied_amount"=>57500, "applied_at"=>1587754637, "txn_status"=>"success", "txn_date"=>1587754636, "txn_amount"=>57500}],
                  :linked_orders=>nil,
                  :billing_address=>{:first_name=>"Willie", :last_name=>"J  Berry", :company=>"The Random Group",
                      :line1=>"3155 W Big Beaver Rd", :city=>"Troy", :state_code=>"[FILTERED]", :state=>"Michigan",
                      :country=>"US", :zip=>"48084", :object=>"billing_address"},
                  :notes=>[{"note"=>"<p><strong>Please always include your invoice number when making any payment!</strong></p>\n<p><span style=\"\n  text-decoration: underline;\n\"><strong><u>Reference to our Bank details:</u></strong></span></p>\n<p>Click the appropriate currency below to view our respective Bank account details for payment processing.</p>\n<p><a href=\"https://www.dropbox.com/s/ntbk24s9ajkwhrs/AUD%20Bank%20Details%20on%20Westpac%20letterhead.pdf?dl&#61;0\"><span class=\"text_\">AUD</span></a> <span class=\"tab\">    </span><a class=\"text_\" href=\"https://www.dropbox.com/s/n2i3owmtj1dvjtt/EUR%2BIBAN%2BMCA%2BPayment%2BInstructions%2B-%2BFreshworks%2BInc.pdf?dl&#61;0\">EUR</a> <span class=\"tab\">    </span><a class=\"text_\" href=\"https://www.dropbox.com/s/577gyls3v6ufq3q/GBP%2BIBAN%2BMCA%2BPayment%2BInstructions%2B-%2BFreshworks%2BInc.pdf?dl&#61;0\">GBP</a> <span class=\"tab\">    </span><a class=\"text_\" href=\"https://www.dropbox.com/s/zcdgto8pmlndqrl/SVB%20Bank%20Letter%20USD.pdf?dl&#61;0\">USD</a></p>\n<p><span style=\"\n  text-decoration: underline;\n\"><strong><u>For Check Payments (US Customers Only)</u></strong></span></p>\n<p><strong>E-checks:</strong> Freshworks Inc, Dept LA 24888, Pasadena CA 91185-4888.</p>\n<p><strong>Physical checks:</strong> Freshworks Inc., 24888, 14005 Live Oak Ave, Irwindale CA 91706-1300.</p>\n<p><strong>Other Payment Methods: </strong>PayPal ID: <a class=\"text_\" href=\"mailto:paypal&#64;freshdesk.com\">paypal&#64;freshdesk.com</a> (USD Only)</p>\n<p>For questions/concerning regarding this invoice, please contact <a href=\"mailto:billing&#64;freshworks.com\">billing&#64;freshworks.com</a></p>\n<p>Click this link to download the <a href=\"https://www.dropbox.com/s/mqnf5fn7ow59rch/Freshworks__W9_2020.pdf?dl&#61;0\"><span class=\"text_\">W9 certificate</span></a></p>"}]}},
          :event_type=>"subscription_changed", :webhook_status=>"scheduled",
          :webhooks=>[{"id"=>"wh_56", "webhook_status"=>"scheduled", "object"=>"webhook"}],
          :digest=>"1be618a2d095a0b718415c231c554c7c", :name_prefix=>"fdadmin_", :path_prefix=>nil,
          :action=>"trigger", :controller=>"fdadmin/billing"
      }
    end
end
