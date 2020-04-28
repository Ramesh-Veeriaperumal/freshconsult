require_relative '../../../api/test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
class Admin::Ecommerce::EbayAccountsControllerTest < ActionController::TestCase
  def setup
    super
  end

  def add_ecommerce_account(parsed_data, configs)
    user_details = Ecommerce::Ebay::Api.new(site_id: parsed_data['ebay_site_id']).make_ebay_api_call(:fetch_user, auth_token: configs['ebay_auth_token'])

    if user_details
      ebay_account = Account.current.ebay_accounts.build(name: parsed_data['ebay_account_name'], group_id: parsed_data['group_id'], product_id: parsed_data['product_id'])
      ebay_account.external_account_id = user_details[:user][:eias_token]
      ebay_account.configs = { auth_token: configs['ebay_auth_token'], site_id: parsed_data['ebay_site_id'], hard_expiration_time: configs['hard_expiration_time'] }
      ebay_account.status = 2
      ebay_account.save
      Ecommerce::Ebay::Api.new(site_id: parsed_data['ebay_site_id']).make_ebay_api_call(:subscribe_to_notifications, auth_token: configs['ebay_auth_token'], enable_type: 'enable')
    end
  end

  def create_an_ecommerce_account(eias_token)
    session[:ebay_session_id] = Faker::Lorem.characters(10)
    session[:ebay_site_id] = '0'
    session[:ebay_account_name] = 'Test account'
    auth_token = { ack: 'Success', ebay_auth_token: Faker::Lorem.characters(20), hard_expiration_time: '2017-01-18T11:18:10.000Z' }

    user_details = { user: { about_me_page: 'false', eias_token: eias_token, email: 'priyo@freshdesk.com',
                             feedback_score: '500', unique_negative_feedback_count: '0', unique_positive_feedback_count: '0', positive_feedback_percent: '0.0', feedback_private: 'false',
                             feedback_rating_star: 'Purple', id_verified: 'true', ebay_good_standing: 'true', new_user: 'false', registration_date: '1995-01-01T00:00:00.000Z', site: 'US',
                             status: 'Confirmed', user_id: 'testuser_priyo456', user_id_changed: 'false', user_id_last_changed: '2015-04-01T14:55:53.000Z', vat_status: 'NoVATTax',
                             seller_info: { allow_payment_edit: 'true', checkout_enabled: 'true', cip_bank_account_stored: 'false', good_standing: 'true', live_auction_authorized: 'false',
                                            merchandizing_pref: 'OptIn', qualifies_for_b2_bvat: 'false', seller_guarantee_level: 'NotEligible', scheduling_info: { max_scheduled_minutes: '30240',
                                                                                                                                                                   min_scheduled_minutes: '0', max_scheduled_items: '3000' }, store_owner: 'true', store_url: 'http://www.stores.sandbox.ebay.com/id=133055377', store_site: 'US',
                                            payment_method: 'NothingOnFile', charity_registered: 'false', safe_payment_exempt: 'true', transaction_percent: '100.0', recoupment_policy_consent: nil,
                                            domestic_rate_table: 'false', international_rate_table: 'false' }, business_role: 'FullMarketPlaceParticipant', pay_pal_account_level: 'Verified',
                             pay_pal_account_type: 'Business', pay_pal_account_status: 'Active', ebay_subscription: 'EBayStoreBasic', user_subscription: 'EBayStoreBasic',
                             ebay_wiki_read_only: 'false', motors_dealer: 'false', unique_neutral_feedback_count: '0', enterprise_seller: 'false' } }

    Ecommerce::Ebay::Api.any_instance.stubs(:fetch_auth_token).returns(auth_token)
    Ecommerce::Ebay::Api.any_instance.stubs(:fetch_user).returns(user_details)
    Ecommerce::Ebay::Api.any_instance.stubs(:subscribe_to_notifications).returns(true)
    parsed_data = { 'ebay_session_id' => session[:ebay_session_id], 'ebay_site_id' => session[:ebay_site_id], 'ebay_account_name' => session[:ebay_account_name] }
    configs = Ecommerce::Ebay::Api.new(site_id: parsed_data['ebay_site_id']).make_ebay_api_call(:fetch_auth_token, session_id: parsed_data['ebay_session_id'])
    add_ecommerce_account(parsed_data, configs)
  end

  def create_ebay_remote_user(eias_token)
    remote_user = Ecommerce::EbayRemoteUser.new(remote_id: eias_token, account_id: Account.current.id)
    remote_user.save
  end

  def test_ecommerce_reply_to_freshdesk
    eias_token = Faker::Lorem.characters(20)
    create_an_ecommerce_account eias_token
    create_ebay_remote_user eias_token
    html_text_body = '<!DOCTYPE html><html><body><table id=area2Container width=100% border=0 cellpadding=0 cellspacing=0 align=center style=border-collapse: collapse border-spacing: border: none background-color:><tr><td>area2Container</td></tr></table><div id=V4EmailHeader1 style=max-height: font-size: overflow:hidden display: none><hr>From: testuser_priyo123<br>To: testuser_priyo456<br>Subject: Details about item: testuser_priyo123 sent a message about Toys fixed2 #110164967546<br>Sent Date: Apr-20-20 02:33:20 PDT</div></body></html>'
    notification = { 'Envelope' => { 'Header' => { 'RequesterCredentials' => { 'NotificationSignature' => 'dw6CaxfcizXKA/XR3PvigQ==', 'mustUnderstand' => '0' } },
                                     'Body' => { 'GetMyMessagesResponse' => { 'Timestamp' => '2015-07-28T14:14:29.887Z', 'Ack' => 'Success', 'CorrelationID' => '636329690', 'Version' => '927',
                                                                              'Build' => 'E927_CORE_APIMSG_17564148_R1', 'NotificationEventName' => 'MyMessagesM2MMessage', 'RecipientUserID' => 'testuser_priyo456',
                                                                              'EIASToken' => eias_token, 'Messages' => { 'Message' => { 'Sender' => 'testuser_priyo123', 'SendingUserID' => '133055376',
                                                                                                                                        'RecipientUserID' => 'testuser_priyo456', 'SendToName' => 'testuser_priyo456', 'Subject' => 'Details about item: testuser_priyo123 sent a message about Toys fixed2 #110164967546',
                                                                                                                                        'MessageID' => '5882110', 'ExternalMessageID' => '1137081010', 'Text' => html_text_body, 'Flagged' => 'false', 'Read' => 'false', 'ReceiveDate' => '2015-07-28T14:14:29.000Z',
                                                                                                                                        'ExpirationDate' => '2016-07-27T14:14:29.000Z', 'ItemID' => '110164967546', 'ResponseDetails' => { 'ResponseEnabled' => 'true',
                                                                                                                                                                                                                                           'ResponseURL' => 'http://contact.sandbox.ebay.com/ws/eBayISAPI.dll?M2MContact&item=110164967546&requested=testuser_priyo123&qid=1137081010&redirect=0&messageid=m5882110' },
                                                                                                                                        'Folder' => { 'FolderID' => '0' }, 'Content' => 'Test', 'MessageType' => 'ContactTransactionPartner', 'Replied' => 'false', 'ItemEndTime' => '2015-08-13T08:51:19.000Z',
                                                                                                                                        'ItemTitle' => 'Toys fixed2' } } } } }, 'action' => 'notify', 'controller' => 'admin/ecommerce/ebay_accounts' }
    Sidekiq::Testing.inline! do
      post :notify, notification
    end
    assert_response 200
  ensure
    @account.ebay_accounts.find_by_external_account_id(eias_token).destroy
    Ecommerce::Ebay::Api.any_instance.unstub(:fetch_auth_token, :fetch_user, :subscribe_to_notifications)
  end
end
