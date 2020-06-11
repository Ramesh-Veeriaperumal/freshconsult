require_relative '../../../api/test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
class Admin::Ecommerce::EbayAccountsControllerTest < ActionController::TestCase
  include ApiTicketsTestHelper

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

  def test_ecommerce_create_incoming_reply
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

  def test_ecommerce_create_ticket_with_incoming_attachments
    eias_token = Faker::Lorem.characters(20)
    create_an_ecommerce_account eias_token
    create_ebay_remote_user eias_token

    notification_subject = 'Details about item: testuser_priyo123 sent a message about Toys fixed2 #110164967547'
    ticket_body_html = '<!DOCTYPE html><html><body><div>Subject: Details about item: testuser_priyo123 sent a message about Toys fixed2 #110164967547</div></body></html>'
    ticket_message_id = '1137081011'
    message_media = { 'MediaURL' => Rails.root.join('test', 'api', 'fixtures', 'files', 'image6mb.jpg'), 'MediaName' => 'image6mb.jpg' }

    notification = { 'Envelope' => { 'Body' => { 'GetMyMessagesResponse' => { 'EIASToken' => eias_token, 'Messages' => { 'Message' => { 'Sender' => 'testuser_priyo123', 'SendingUserID' => '133055376',
                                                                                                                                        'Subject' => notification_subject,
                                                                                                                                        'MessageID' => '5882110', 'ExternalMessageID' => ticket_message_id, 'Text' => ticket_body_html, 'MessageMedia' => message_media,
                                                                                                                                        'ItemID' => '110164967547' } } } } }, 'action' => 'notify', 'controller' => 'admin/ecommerce/ebay_accounts' }
    Sidekiq::Testing.inline! do
      post :notify, notification
    end
    assert_response 200
    assert_equal Account.current.tickets.where(subject: notification_subject).last.inline_attachments.count, 1
  ensure
    @account.ebay_accounts.where(external_account_id: eias_token).last.destroy
    Ecommerce::Ebay::Api.any_instance.unstub(:fetch_auth_token, :fetch_user, :subscribe_to_notifications)
  end

  def test_ecommerce_reply_create_note_with_incoming_attachments
    eias_token = Faker::Lorem.characters(20)
    create_an_ecommerce_account eias_token
    create_ebay_remote_user eias_token

    ebay_ticket = create_ebay_ticket
    notification_subject = 'Details about item: testuser_priyo123 sent a message about Toys fixed2 #110164967548'
    note_body = 'Reply about Toys fixed2 #110164967548'
    note_body_html = '<!DOCTYPE html><html><body><div>Reply about Toys fixed2 #110164967548</div></body></html>'
    note_message_id = '1137081012'
    message_media = { 'MediaURL' => Rails.root.join('test', 'api', 'fixtures', 'files', 'image6mb.jpg'), 'MediaName' => 'image6mb.jpg' }

    notification = { 'Envelope' => { 'Body' => { 'GetMyMessagesResponse' => { 'EIASToken' => eias_token, 'Messages' => { 'Message' => { 'Sender' => 'testuser_priyo123', 'SendingUserID' => '133055376',
                                                                                                                                        'Subject' => notification_subject,
                                                                                                                                        'MessageID' => '5882110', 'ExternalMessageID' => note_message_id, 'Text' => note_body_html, 'MessageMedia' => message_media,
                                                                                                                                        'ItemID' => '110164967547' } } } } }, 'action' => 'notify', 'controller' => 'admin/ecommerce/ebay_accounts' }
    Ecommerce::Ebay::Processor.any_instance.stubs(:check_parent_ticket).returns(ebay_ticket)
    Sidekiq::Testing.inline! do
      post :notify, notification
    end
    assert_response 200
    assert_equal Account.current.tickets.where(subject: ebay_ticket.subject).last.notes.last.inline_attachments.count, 1
  ensure
    @account.ebay_accounts.where(external_account_id: eias_token).last.destroy
    Ecommerce::Ebay::Api.any_instance.unstub(:fetch_auth_token, :fetch_user, :subscribe_to_notifications, :check_parent_ticket)
  end

  def test_ecommerce_reply_from_ebay_sent_folder
    eias_token = Faker::Lorem.characters(20)
    create_an_ecommerce_account eias_token
    create_ebay_remote_user eias_token
    notification = { 'Envelope' => { 'Body' => { 'GetMyMessagesResponse' => { 'EIASToken' => eias_token, 'Messages' => { 'Message' => { 'Sender' => 'testuser_priyo123', 'SendingUserID' => '133055376',
                                                                                                                                        'Subject' => 'testuser_priyo123 sent a message',
                                                                                                                                        'MessageID' => '5882110', 'ExternalMessageID' => '1137081010', 'Text' => 'Test',
                                                                                                                                        'ItemTitle' => 'Toys fixed2' } } } } } }
    sent_messages = [{ sender: 'testuser_priyo456', sending_user_id: '133055377', send_to_name: 'bssmb_us_06',
                       subject: 'Details about item: testuser_priyo456 sent a message about item #110162958894',
                       message_id: '5879180', external_message_id: '1136421010', item_id: '110162958894' },
                     { sender: 'testuser_priyo456', sending_user_id: '133055377', send_to_name: 'bssmb_us_03',
                       subject: 'Details about item: testuser_priyo456 sent a message about item #110146234712',
                       message_id: '5879110', external_message_id: '1136413010', item_id: '110146234712' }]

    message = { messages: { message: { sender: 'eBay - cmedia_group', sending_user_id: '1073158010', send_to_name: 'john1984_123',
                                       subject: 'Re: I have a question about using my item #371374902426',
                                       message_id: '69943180680', external_message_id: '1115863692010', text: 'Test message', item_id: '371374902426' } } }

    Ecommerce::Ebay::Processor.any_instance.stubs(:fetch_user_sent_messages).returns(sent_messages)
    Ecommerce::Ebay::Processor.any_instance.stubs(:fetch_message).returns(message)

    Sidekiq::Testing.inline! do
      post :notify, notification
    end
    assert_response 200
  ensure
    @account.ebay_accounts.where(external_account_id: eias_token).last.destroy
    Ecommerce::Ebay::Api.any_instance.unstub(:fetch_auth_token, :fetch_user, :subscribe_to_notifications, :fetch_user_sent_messages, :fetch_message)
  end
end
