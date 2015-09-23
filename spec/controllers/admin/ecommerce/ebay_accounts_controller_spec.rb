require 'spec_helper'
require 'sidekiq/testing'

describe Admin::Ecommerce::EbayAccountsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account.features.ecommerce.create
  end

  before(:each) do
    login_admin
  end

  it "should list all ecommerce accounts" do
    get :new
    response.should render_template "admin/ecommerce/ebay_accounts/new"
  end

  it "should redirect to ebay signin page for create" do
    session = {:session_id=>"NnoDAA**d3f256d314e0a471e4b22112fffffcc1"}
    Ecommerce::Ebay::Api.any_instance.stubs(:fetch_session_id).returns(session)
    post :generate_session, {"ebay_account"=>{"name"=>"First account", "ebay_site_id"=>"203"}}
    response.should redirect_to("#{EbayConfig::AUTHORIZE_URL}&RUName=#{Ebayr.ru_name}&SessID=NnoDAA**d3f256d314e0a471e4b22112fffffcc1&ruparams=account_url%3Dhttp%253A%252F%252Flocalhost.freshpo.com")
  end

  it "should not redirect to ebay signin page for create" do
    session = false
    Ecommerce::Ebay::Api.any_instance.stubs(:fetch_session_id).returns(session)
    post :generate_session, {"ebay_account"=>{"name"=>"First account", "ebay_site_id"=>"203"}}
    response.should redirect_to("/admin/ecommerce/accounts")
  end


  it "should redirect to enable" do
    get :authorize ,{"isAuthSuccessful"=>"true", "username"=>"testuser_priyo456", "account_url"=>"http://localhost.freshpo.com"}
    response.should redirect_to("/admin/ecommerce/ebay_accounts/enable?ebay_account_id=")
  end

  it "should redirect to failure" do
    get :authorize ,{"isAuthSuccessful"=>"false", "username"=>"testuser_priyo456", "account_url"=>"http://localhost.freshpo.com"}
    response.should redirect_to("/admin/ecommerce/ebay_accounts/failure")
  end

  it "should add a new ecommerce account" do
    ebay_acc_count = @account.ebay_accounts.count
    session[:ebay_session_id] = "NnoDAA**d3f256d314e0a471e4b22112fffffcc1"
    session[:ebay_site_id] = "0"
    session[:ebay_account_name] = "Test account"
    auth_token = {:ack=>"Success", :ebay_auth_token=>"AgAAAA**AQAAAA**aAAAAA**8mS3VQ**nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wFk4GhDZWBpgudj6x9nY+seQ**NnoDAA**AAMAAA**ewRd8vErNghcK
      tTBMjCZGzpqIk95HXbzAEBwM5YiMv5Fvj1W6S0sIdGMTiLY/qCHa0jvC7l7jPS9yFmwE9WQIrlMEUzcLJMDEX2IfH7Le0IZ5rZvmyAT87WNTkBMSlTX5bXl7SxQ8IXit269QWOsu5c3CAo5n0Tg04Q9FZJp+4Ub
      yPOBduE6coaCtF1MHsq5o3PhnBBXBb1zElYzmj0/yEKv9U+g8pqhlpHOq70dPuIkA2XQ/VNpQn50GmpgMRKLYXRggAja6OTiSS4q+vX9DjEWncPVtfpoV+A/Dnw30QC/ng2Q9wIj5DSWDpW8coI62+5rKrpAYEco
      MGM/8sz9oP1xl35g3fUNVwqhWtmmfLdftzcY2bkFYH7EAZDs02VBBgWZKj4rOrHXSRXoU2GsvS0jWk01iTShSbsVz8kqR6ohhPeSXQAQWQG8Jyuai6CrUkCiYzuCAmtVLwFY8akypQJiP24K3mR7g/jlTiX2JtTt0awO
      PIrsK/wS075qFekA1I9NbeQK7GpROtVslYsNBo22lPeHaK5HwJ1X5Kz96q0s7dJaDkPmDmOnNrM2r/0I9bI7ac2YGGGNHj0iF3LxqFFs2eO325JCWZhzoiRj1F/LaPGeEMLmqOyBIwPf1lrKlLilirievg1mNZsj8yIUMp
      vv+xNaCUTptlnrqscDs6XMLf5yeYuPY7E8oEGI6eYm1HVaGtsuzYB8jafcC/PiKfWRjMKmkEgMtOk+/62AboHxUWO2Q+nLLC2xHWQR3ndR", :hard_expiration_time=>"2017-01-18T11:18:10.000Z"}


    user_details = { :user=>{:about_me_page=>"false", :eias_token=>"nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wFk4GhDZWBpgudj6x9nY+seQ==", :email=>"priyo@freshdesk.com", 
      :feedback_score=>"500", :unique_negative_feedback_count=>"0", :unique_positive_feedback_count=>"0", :positive_feedback_percent=>"0.0", :feedback_private=>"false", 
      :feedback_rating_star=>"Purple", :id_verified=>"true", :ebay_good_standing=>"true", :new_user=>"false", :registration_date=>"1995-01-01T00:00:00.000Z", :site=>"US", 
      :status=>"Confirmed", :user_id=>"testuser_priyo456", :user_id_changed=>"false", :user_id_last_changed=>"2015-04-01T14:55:53.000Z", :vat_status=>"NoVATTax", 
      :seller_info=>{:allow_payment_edit=>"true", :checkout_enabled=>"true", :cip_bank_account_stored=>"false", :good_standing=>"true", :live_auction_authorized=>"false",
      :merchandizing_pref=>"OptIn", :qualifies_for_b2_bvat=>"false", :seller_guarantee_level=>"NotEligible", :scheduling_info=>{:max_scheduled_minutes=>"30240", 
      :min_scheduled_minutes=>"0", :max_scheduled_items=>"3000"}, :store_owner=>"true", :store_url=>"http://www.stores.sandbox.ebay.com/id=133055377", :store_site=>"US", 
      :payment_method=>"NothingOnFile", :charity_registered=>"false", :safe_payment_exempt=>"true", :transaction_percent=>"100.0", :recoupment_policy_consent=>nil, 
      :domestic_rate_table=>"false", :international_rate_table=>"false"}, :business_role=>"FullMarketPlaceParticipant", :pay_pal_account_level=>"Verified",
      :pay_pal_account_type=>"Business", :pay_pal_account_status=>"Active", :ebay_subscription=>"EBayStoreBasic", :user_subscription=>"EBayStoreBasic", 
      :ebay_wiki_read_only=>"false", :motors_dealer=>"false", :unique_neutral_feedback_count=>"0", :enterprise_seller=>"false"}}


    Ecommerce::Ebay::Api.any_instance.stubs(:fetch_auth_token).returns(auth_token)
    Ecommerce::Ebay::Api.any_instance.stubs(:fetch_user).returns(user_details)
    Ecommerce::Ebay::Api.any_instance.stubs(:subscribe_to_notifications).returns(true)
    get :enable
    @account.ebay_accounts.count.size.should be > ebay_acc_count
  end


  it "should fail to add a new ecommerce account" do
    ebay_acc_count = @account.ebay_accounts.count
    session[:ebay_session_id] = "NnoDAA**d3f256d314e0a471e4b22112fffffcc1"
    session[:ebay_site_id] = "0"
    session[:ebay_account_name] = "Test account"
    auth_token = {:ack=>"Success", :ebay_auth_token=>"AgAAAA**AQAAAA**aAAAAA**8mS3VQ**nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wFk4GhDZWBpgudj6x9nY+seQ**NnoDAA**AAMAAA**ewRd8vErNghcK
      tTBMjCZGzpqIk95HXbzAEBwM5YiMv5Fvj1W6S0sIdGMTiLY/qCHa0jvC7l7jPS9yFmwE9WQIrlMEUzcLJMDEX2IfH7Le0IZ5rZvmyAT87WNTkBMSlTX5bXl7SxQ8IXit269QWOsu5c3CAo5n0Tg04Q9FZJp+4Ub
      yPOBduE6coaCtF1MHsq5o3PhnBBXBb1zElYzmj0/yEKv9U+g8pqhlpHOq70dPuIkA2XQ/VNpQn50GmpgMRKLYXRggAja6OTiSS4q+vX9DjEWncPVtfpoV+A/Dnw30QC/ng2Q9wIj5DSWDpW8coI62+5rKrpAYEco
      MGM/8sz9oP1xl35g3fUNVwqhWtmmfLdftzcY2bkFYH7EAZDs02VBBgWZKj4rOrHXSRXoU2GsvS0jWk01iTShSbsVz8kqR6ohhPeSXQAQWQG8Jyuai6CrUkCiYzuCAmtVLwFY8akypQJiP24K3mR7g/jlTiX2JtTt0awO
      PIrsK/wS075qFekA1I9NbeQK7GpROtVslYsNBo22lPeHaK5HwJ1X5Kz96q0s7dJaDkPmDmOnNrM2r/0I9bI7ac2YGGGNHj0iF3LxqFFs2eO325JCWZhzoiRj1F/LaPGeEMLmqOyBIwPf1lrKlLilirievg1mNZsj8yIUMp
      vv+xNaCUTptlnrqscDs6XMLf5yeYuPY7E8oEGI6eYm1HVaGtsuzYB8jafcC/PiKfWRjMKmkEgMtOk+/62AboHxUWO2Q+nLLC2xHWQR3ndR", :hard_expiration_time=>"2017-01-18T11:18:10.000Z"}


    user_details = { :user=>{:about_me_page=>"false", :eias_token=>"nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wFk4GhDZWBpgudj6x9nY+seQ==", :email=>"priyo@freshdesk.com", 
      :feedback_score=>"500", :unique_negative_feedback_count=>"0", :unique_positive_feedback_count=>"0", :positive_feedback_percent=>"0.0", :feedback_private=>"false", 
      :feedback_rating_star=>"Purple", :id_verified=>"true", :ebay_good_standing=>"true", :new_user=>"false", :registration_date=>"1995-01-01T00:00:00.000Z", :site=>"US", 
      :status=>"Confirmed", :user_id=>"testuser_priyo456", :user_id_changed=>"false", :user_id_last_changed=>"2015-04-01T14:55:53.000Z", :vat_status=>"NoVATTax", 
      :seller_info=>{:allow_payment_edit=>"true", :checkout_enabled=>"true", :cip_bank_account_stored=>"false", :good_standing=>"true", :live_auction_authorized=>"false",
      :merchandizing_pref=>"OptIn", :qualifies_for_b2_bvat=>"false", :seller_guarantee_level=>"NotEligible", :scheduling_info=>{:max_scheduled_minutes=>"30240", 
      :min_scheduled_minutes=>"0", :max_scheduled_items=>"3000"}, :store_owner=>"true", :store_url=>"http://www.stores.sandbox.ebay.com/id=133055377", :store_site=>"US", 
      :payment_method=>"NothingOnFile", :charity_registered=>"false", :safe_payment_exempt=>"true", :transaction_percent=>"100.0", :recoupment_policy_consent=>nil, 
      :domestic_rate_table=>"false", :international_rate_table=>"false"}, :business_role=>"FullMarketPlaceParticipant", :pay_pal_account_level=>"Verified",
      :pay_pal_account_type=>"Business", :pay_pal_account_status=>"Active", :ebay_subscription=>"EBayStoreBasic", :user_subscription=>"EBayStoreBasic", 
      :ebay_wiki_read_only=>"false", :motors_dealer=>"false", :unique_neutral_feedback_count=>"0", :enterprise_seller=>"false"}}


    Ecommerce::Ebay::Api.any_instance.stubs(:fetch_auth_token).returns(auth_token)
    Ecommerce::Ebay::Api.any_instance.stubs(:fetch_user).returns(user_details)
    Ecommerce::Ebay::Api.any_instance.stubs(:subscribe_to_notifications).returns(false)
    get :enable
    @account.ebay_accounts.count.size.should be > ebay_acc_count
  end

  it "should redirect to ebay signin page for revoke" do
    session = {:session_id=>"NnoDAA**d3f256d314e0a471e4b22112fffffcc1"}
    Ecommerce::Ebay::Api.any_instance.stubs(:fetch_session_id).returns(session)
    get :revoke_token, {:id => @account.ebay_accounts.first.id, "ebay_account"=>{"name"=>"First account", "ebay_site_id"=>"203"}}
    response.should redirect_to("#{EbayConfig::AUTHORIZE_URL}&RUName=#{Ebayr.ru_name}&SessID=NnoDAA**d3f256d314e0a471e4b22112fffffcc1&ruparams=account_url%3Dhttp%253A%252F%252Flocalhost.freshpo.com%26ebay_account_id%3D#{@account.ebay_accounts.first.id}")
  end

  it "should update auth token for revoke" do

    session[:ebay_session_id] = "NnoDAA**d3f256d314e0a471e4b22112fffffcc1"
    session[:ebay_site_id] = "0"
    session[:ebay_account_name] = "Test account"
    auth_token = {:ack=>"Success", :ebay_auth_token=>"AgAAAA**AQAAAA**aAAAAA**8mS3VQ**nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wFk4GhDZWBpgudj6x9nY+seQ**NnoDAA**AAMAAA**ewRd8vErNghcK
      tTBMjCZGzpqIk95HXbzAEBwM5YiMv5Fvj1W6S0sIdGMTiLY/qCHa0jvC7l7jPS9yFmwE9WQIrlMEUzcLJMDEX2IfH7Le0IZ5rZvmyAT87WNTkBMSlTX5bXl7SxQ8IXit269QWOsu5c3CAo5n0Tg04Q9FZJp+4Ub
      yPOBduE6coaCtF1MHsq5o3PhnBBXBb1zElYzmj0/yEKv9U+g8pqhlpHOq70dPuIkA2XQ/VNpQn50GmpgMRKLYXRggAja6OTiSS4q+vX9DjEWncPVtfpoV+A/Dnw30QC/ng2Q9wIj5DSWDpW8coI62+5rKrpAYEco
      MGM/8sz9oP1xl35g3fUNVwqhWtmmfLdftzcY2bkFYH7EAZDs02VBBgWZKj4rOrHXSRXoU2GsvS0jWk01iTShSbsVz8kqR6ohhPeSXQAQWQG8Jyuai6CrUkCiYzuCAmtVLwFY8akypQJiP24K3mR7g/jlTiX2JtTt0awO
      PIrsK/wS075qFekA1I9NbeQK7GpROtVslYsNBo22lPeHaK5HwJ1X5Kz96q0s7dJaDkPmDmOnNrM2r/0I9bI7ac2YGGGNHj0iF3LxqFFs2eO325JCWZhzoiRj1F/LaPGeEMLmqOyBIwPf1lrKlLilirievg1mNZsj8yIUMp
      vv+xNaCUTptlnrqscDs6XMLf5yeYuPY7E8oEGI6eYm1HVaGtsuzYB8jafcC/PiKfWRjMKmkEgMtOk+/62AboHxUWO2Q+nLLC2xHWQR3ndR", :hard_expiration_time=>"2017-01-18T11:18:10.000Z"}

      Ecommerce::Ebay::Api.any_instance.stubs(:fetch_auth_token).returns(auth_token)
      get :enable, {"ebay_account_id" => @account.ebay_accounts.first.id}
      response.should redirect_to("/admin/ecommerce/accounts")
  end

  it "should update ebay account" do
    put :update, {"ecommerce_ebay_account"=>{"name"=>"bssmb_us_11"}, "id"=> @account.ebay_accounts.first.id}
    @account.ebay_accounts.first.name.should eq("bssmb_us_11")
  end

  it "should fail to update ebay account" do
    put :update, {"ecommerce_ebay_account"=>{"names"=>"bssmb_us_11"}, "id"=> @account.ebay_accounts.first.id}
    @account.ebay_accounts.first.name.should eq("bssmb_us_11")
  end

  it "should create ticket with notification" do
    Sidekiq::Testing.inline!
    notification = {"Envelope"=>{"Header"=>{"RequesterCredentials"=>{"NotificationSignature"=>"dw6CaxfcizXKA/XR3PvigQ==", "mustUnderstand"=>"0"}}, 
    "Body"=>{"GetMyMessagesResponse"=>{"Timestamp"=>"2015-07-28T14:14:29.887Z", "Ack"=>"Success", "CorrelationID"=>"636329690", "Version"=>"927", 
    "Build"=>"E927_CORE_APIMSG_17564148_R1", "NotificationEventName"=>"MyMessagesM2MMessage", "RecipientUserID"=>"testuser_priyo456", 
    "EIASToken"=>"nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wFk4GhDZWBpgudj6x9nY+seQ==", "Messages"=>{"Message"=>{"Sender"=>"testuser_priyo123", "SendingUserID"=>"133055376", 
    "RecipientUserID"=>"testuser_priyo456", "SendToName"=>"testuser_priyo456", "Subject"=>"Details about item: testuser_priyo123 sent a message about Toys fixed2 #110164967546", 
    "MessageID"=>"5882110", "ExternalMessageID"=>"1137081010", "Text"=>"Test", "Flagged"=>"false", "Read"=>"false", "ReceiveDate"=>"2015-07-28T14:14:29.000Z", 
    "ExpirationDate"=>"2016-07-27T14:14:29.000Z", "ItemID"=>"110164967546", "ResponseDetails"=>{"ResponseEnabled"=>"true", 
    "ResponseURL"=>"http://contact.sandbox.ebay.com/ws/eBayISAPI.dll?M2MContact&item=110164967546&requested=testuser_priyo123&qid=1137081010&redirect=0&messageid=m5882110"}, 
    "Folder"=>{"FolderID"=>"0"}, "Content"=>"Test", "MessageType"=>"ContactTransactionPartner", "Replied"=>"false", "ItemEndTime"=>"2015-08-13T08:51:19.000Z", 
    "ItemTitle"=>"Toys fixed2"}}}}}, "action"=>"notify", "controller"=>"admin/ecommerce/ebay_accounts"}

    post :notify, notification
    response.status.should eql(200)
    Sidekiq::Testing.disable!
  end

  it "should create note with notification" do
    Sidekiq::Testing.inline!

    notification = {"Envelope"=>{"Header"=>{"RequesterCredentials"=>{"NotificationSignature"=>"dw6CaxfcizXKA/XR3PvigQ==", "mustUnderstand"=>"0"}}, 
    "Body"=>{"GetMyMessagesResponse"=>{"Timestamp"=>"2015-07-28T14:14:29.887Z", "Ack"=>"Success", "CorrelationID"=>"636329690", "Version"=>"927", 
    "Build"=>"E927_CORE_APIMSG_17564148_R1", "NotificationEventName"=>"MyMessagesM2MMessage", "RecipientUserID"=>"testuser_priyo456", 
    "EIASToken"=>"nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wFk4GhDZWBpgudj6x9nY+seQ==", "Messages"=>{"Message"=>{"Sender"=>"testuser_priyo123", "SendingUserID"=>"133055376", 
    "RecipientUserID"=>"testuser_priyo456", "SendToName"=>"testuser_priyo456", "Subject"=>"Details about item: testuser_priyo123 sent a message about Toys fixed2 #110164967546", 
    "MessageID"=>"5882110", "ExternalMessageID"=>"1137081010", "Text"=>"Test", "Flagged"=>"false", "Read"=>"false", "ReceiveDate"=>"2015-07-28T14:14:29.000Z", 
    "ExpirationDate"=>"2016-07-27T14:14:29.000Z", "ItemID"=>"110164967546", "ResponseDetails"=>{"ResponseEnabled"=>"true", 
    "ResponseURL"=>"http://contact.sandbox.ebay.com/ws/eBayISAPI.dll?M2MContact&item=110164967546&requested=testuser_priyo123&qid=1137081010&redirect=0&messageid=m5882110"}, 
    "Folder"=>{"FolderID"=>"0"}, "Content"=>"Test", "MessageType"=>"ContactTransactionPartner", "Replied"=>"false", "ItemEndTime"=>"2015-08-13T08:51:19.000Z", 
    "ItemTitle"=>"Toys fixed2"}}}}}, "action"=>"notify", "controller"=>"admin/ecommerce/ebay_accounts"}
    post :notify, notification
    response.status.should eql(200)
    Sidekiq::Testing.disable!
  end

  it "should create ticket from ebay sent folder" do
    Sidekiq::Testing.inline!
    notification = {"Envelope"=>{"Header"=>{"RequesterCredentials"=>{"NotificationSignature"=>"dw6CaxfcizXKA/XR3PvigQ==", "mustUnderstand"=>"0"}}, 
      "Body"=>{"GetMyMessagesResponse"=>{"Timestamp"=>"2015-07-28T14:14:29.887Z", "Ack"=>"Success", "CorrelationID"=>"636329690", "Version"=>"927", 
      "Build"=>"E927_CORE_APIMSG_17564148_R1", "NotificationEventName"=>"MyMessagesM2MMessage", "RecipientUserID"=>"testuser_priyo456", 
      "EIASToken"=>"nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wFk4GhDZWBpgudj6x9nY+seQ==", "Messages"=>{"Message"=>{"Sender"=>"testuser_priyo123", "SendingUserID"=>"133055376", 
      "RecipientUserID"=>"testuser_priyo456", "SendToName"=>"testuser_priyo456", "Subject"=>"testuser_priyo123 sent a message", 
      "MessageID"=>"5882110", "ExternalMessageID"=>"1137081010", "Text"=>"Test", "Flagged"=>"false", "Read"=>"false", "ReceiveDate"=>"2015-07-28T14:14:29.000Z", 
      "ExpirationDate"=>"2016-07-27T14:14:29.000Z", "ResponseDetails"=>{"ResponseEnabled"=>"true", 
      "ResponseURL"=>"http://contact.sandbox.ebay.com/ws/eBayISAPI.dll?M2MContact&item=110164967546&requested=testuser_priyo123&qid=1137081010&redirect=0&messageid=m5882110"}, 
      "Folder"=>{"FolderID"=>"0"}, "Content"=>"Test", "MessageType"=>"ContactTransactionPartner", "Replied"=>"false", "ItemEndTime"=>"2015-08-13T08:51:19.000Z", 
      "ItemTitle"=>"Toys fixed2"}}}}}}

      sent_messages = [{:sender=>"testuser_priyo456", :sending_user_id=>"133055377", :recipient_user_id=>"testuser_priyo456", 
        :send_to_name=>"bssmb_us_06", :subject=>"Details about item: testuser_priyo456 sent a message about item #110162958894", 
        :message_id=>"5879180", :external_message_id=>"1136421010", :flagged=>"false", :read=>"true", :receive_date=>"2015-06-22T12:33:59.000Z", 
        :expiration_date=>"2016-06-21T12:33:59.000Z", :item_id=>"110162958894", :response_details=>{:response_enabled=>"false"}, :folder=>{:folder_id=>"1"}, 
        :message_type=>"AskSellerQuestion", :replied=>"false", :item_end_time=>"2015-07-04T12:03:00.000Z", :item_title=>"固定价刊登范本US-yzy"}, 
        {:sender=>"testuser_priyo456", :sending_user_id=>"133055377", :recipient_user_id=>"testuser_priyo456", :send_to_name=>"bssmb_us_03", 
        :subject=>"Details about item: testuser_priyo456 sent a message about 3D Transparent Water drop Raindrop Slim Case Cover For iPhone 5 New Hot Yell #110146234712",
        :message_id=>"5879110", :external_message_id=>"1136413010", :flagged=>"false", :read=>"true", :receive_date=>"2015-06-22T10:42:33.000Z", 
        :expiration_date=>"2016-06-21T10:42:33.000Z", :item_id=>"110146234712", :response_details=>{:response_enabled=>"false"}, 
        :folder=>{:folder_id=>"1"}, :message_type=>"AskSellerQuestion", :replied=>"false", :item_end_time=>"2015-06-25T13:44:14.000Z", 
        :item_title=>"3D Transparent Water drop Raindrop Slim Case Cover For iPhone 5 New Hot Yell"}]

      message = {:timestamp=>"2015-07-29T09:06:15.727Z", :ack=>"Success", :version=>"933", :build=>"E933_INTL_APIMSG_17617226_R1",
        :messages=>{:message=>{:sender=>"eBay - cmedia_group", :sending_user_id=>"1073158010", :recipient_user_id=>"cmedia_group", 
        :send_to_name=>"john1984_123", :subject=>"Re: I have a question about using my item or I want to send the seller
        a message: john1984_123 sent a message about Longman Photo Dictionary (British English ELT) By Marilyn S. Rosenthal, Daniel #371374902426", 
        :message_id=>"69943180680", :external_message_id=>"1115863692010", :text=>"Test message", :flagged=>"false", :read=>"true", 
        :receive_date=>"2015-07-23T11:09:44.000Z", :expiration_date=>"2016-07-22T11:09:43.000Z", :item_id=>"371374902426", 
        :response_details=>{:response_enabled=>"false"}, :folder=>{:folder_id=>"1"}, :content=>"Test message", :message_type=>"ResponseToASQQuestion", 
        :replied=>"false", :item_end_time=>"2015-07-10T19:39:18.000Z", :item_title=>"Longman Photo Dictionary (British English ELT) By Marilyn S. Rosenthal, Daniel"}}}

      Ecommerce::Ebay::Processor.any_instance.stubs(:fetch_user_sent_messages).returns(sent_messages)

      Ecommerce::Ebay::Processor.any_instance.stubs(:fetch_message).returns(message)

      post :notify, notification
      response.status.should eql(200)
      Sidekiq::Testing.disable!
  end

  it "should update user details" do
    Sidekiq::Testing.inline!
    item_notification = {"Envelope"=>{"Header"=>{"RequesterCredentials"=>{"NotificationSignature"=>"23x1viSOqJp9TiZZJS/5GA==", "mustUnderstand"=>"0"}}, 
    "Body"=>{"GetItemTransactionsResponse"=>{"Timestamp"=>"2015-07-29T07:12:07.061Z", "Ack"=>"Success", "CorrelationID"=>"636330020", "Version"=>"927", 
      "Build"=>"E927_CORE_APIMSG_17564148_R1", "NotificationEventName"=>"FixedPriceTransaction", "RecipientUserID"=>"testuser_priyo456", 
      "EIASToken"=>"nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wFk4GhDZWBpgudj6x9nY+seQ==", "PaginationResult"=>{"TotalNumberOfPages"=>"1", "TotalNumberOfEntries"=>"1"}, 
      "HasMoreTransactions"=>"false", "TransactionsPerPage"=>"100", "PageNumber"=>"1", "ReturnedTransactionCountActual"=>"1", "Item"=>{"AutoPay"=>"false", 
      "BuyItNowPrice"=>"0.0", "Currency"=>"USD", "ItemID"=>"110164967546", "ListingType"=>"StoresFixedPrice", 
      "IntegratedMerchantCreditCardEnabled"=>"false", "ConditionID"=>"1000", "ConditionDisplayName"=>"New"}, "TransactionArray"=>{"Transaction"=>{"AmountPaid"=>"0.0", 
      "AdjustmentAmount"=>"0.0", "ConvertedAdjustmentAmount"=>"0.0", "Buyer"=>{"AboutMePage"=>"false", "EIASToken"=>"nY+sHZ2PrBmdj6wVnY+sEZ2PrA2dj6wFk4GhDZWBpgqdj6x9nY+seQ==",
      "Email"=>"priyotech@rediffmail.com", "FeedbackScore"=>"500", "PositiveFeedbackPercent"=>"0.0", "FeedbackPrivate"=>"false", "FeedbackRatingStar"=>"Purple", 
      "IDVerified"=>"true", "eBayGoodStanding"=>"true", "NewUser"=>"false", "RegistrationDate"=>"1995-01-01T00:00:00.000Z", "Site"=>"US", "Status"=>"Confirmed", 
      "UserID"=>"testuser_priyo123", "UserIDChanged"=>"false", "UserIDLastChanged"=>"2015-04-01T14:54:19.000Z", "VATStatus"=>"NoVATTax", 
      "BuyerInfo"=>{"ShippingAddress"=>{"Name"=>"Test User", "Street1"=>"address", "CityName"=>"city", "StateOrProvince"=>"WA", "Country"=>"US", 
      "CountryName"=>"United States", "Phone"=>"(180) 011-1111 ext.: 1", "PostalCode"=>"98102", "AddressID"=>"7335988", "AddressOwner"=>"eBay", 
      "AddressUsage"=>"DefaultShipping"}}, "UserAnonymized"=>"false", "StaticAlias"=>"testus_etwl3358sgfx@v3smtpm2m.qa.ebay.com"}, 
      "ShippingDetails"=>{"ChangePaymentInstructions"=>"true", "PaymentEdited"=>"false", "SalesTax"=>{"SalesTaxPercent"=>"0.0", "ShippingIncludedInTax"=>"false"}, 
      "ShippingServiceOptions"=>{"ShippingService"=>"Other", "ShippingServiceCost"=>"0.0", "ShippingServiceAdditionalCost"=>"0.0", "ShippingServicePriority"=>"1", 
      "ExpeditedService"=>"false", "ShippingTimeMin"=>"1", "ShippingTimeMax"=>"10"}, "ShippingType"=>"Flat", "SellingManagerSalesRecordNumber"=>"119", 
      "ThirdPartyCheckout"=>"false", "TaxTable"=>nil, "GetItFast"=>"false"}, "ConvertedAmountPaid"=>"0.0", "ConvertedTransactionPrice"=>"5.0", 
      "CreatedDate"=>"2015-07-29T07:12:02.000Z", "DepositType"=>"None", "QuantityPurchased"=>"1", "Status"=>{"eBayPaymentStatus"=>"NoPaymentFailure", 
      "CheckoutStatus"=>"CheckoutIncomplete", "LastTimeModified"=>"2015-07-29T07:12:02.000Z", "PaymentMethodUsed"=>"None", "CompleteStatus"=>"Incomplete", 
      "BuyerSelectedShipping"=>"false", "PaymentHoldStatus"=>"None", "IntegratedMerchantCreditCardEnabled"=>"false"}, "TransactionID"=>"27528441001",
      "TransactionPrice"=>"5.0", "BestOfferSale"=>"false", "ShippingServiceSelected"=>{"ShippingService"=>"Other", "ShippingServiceCost"=>"0.0"}, 
      "ContainingOrder"=>{"OrderID"=>"110164967546-27528441001", "OrderStatus"=>"Active"},"PayPalEmailAddress"=>"priyo@freshdesk.com"}}}}}}
    post :notify, item_notification
    response.status.should eql(200)
    Sidekiq::Testing.disable!
  end

  it "should delete ebay account" do
    ebay_acc_count = @account.ebay_accounts.count
    put :destroy, {:id => @account.ebay_accounts.first.id }
    ebay_acc_count.should be < @account.ebay_accounts.count.size
  end


end