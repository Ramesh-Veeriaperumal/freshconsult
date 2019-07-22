require_relative '../../test_helper.rb'
require 'sidekiq/testing'
require 'webmock/minitest'
Sidekiq::Testing.fake!

class Admin::ApiAccountsControllerTest < ActionController::TestCase
  include ApiAccountHelper
  include Redis::OthersRedis
  CHARGEBEE_SUBSCRIPTION_BASE_URL = "https://freshpo-test.chargebee.com/api/v1/subscriptions"
  SUPPORT_CONTACTS_RESPONSE = [{ 'active' => true, 'address' => nil, 'company_id' => 854_881,
                                 'description' => nil, 'email' => 'sample@freshdesk.com', 'id' => 28_271_068,
                                 'job_title' => nil, 'language' => 'en', 'mobile' => nil, 'name' => 'Jeff Brown',
                                 'phone' => nil, 'time_zone' => 'Chennai', 'twitter_id' => nil,
                                 'custom_fields' => { 'subscription' => nil, 'community_champion' => nil,
                                                      'trailblazer' => nil, 'steamroller' => nil, 'community_shaker' => nil,
                                                      'storyteller' => nil, 'community_wizard' => nil }, 'facebook_id' => nil,
                                 'created_at' => '2019-01-14T19:38:37Z', 'updated_at' => '2019-05-13T19:20:12Z',
                                 'unique_external_id' => nil }].freeze
  SUPPORT_TICKETS_RESPONSE = [{ 'cc_emails' => [], 'fwd_emails' => [], 'reply_cc_emails' => [], 'ticket_cc_emails' => [],
                                'fr_escalated' => false, 'spam' => false, 'email_config_id' => nil, 'group_id' => 2,
                                'priority' => 1, 'requester_id' => 1_012_739, 'responder_id' => 27_886_503, 'source' => 7,
                                'company_id' => 79_006, 'status' => 5, 'subject' => 'Conversation with Support check',
                                'association_type' => nil, 'to_emails' => nil, 'product_id' => nil, 'id' => 3_646_780,
                                'type' => "L1 - How To's", 'due_by' => '2019-05-31T23:30:00Z', 'fr_due_by' => '2019-05-29T16:08:37Z',
                                'is_escalated' => false, 'custom_fields' => { 'sub_category' => nil, 'item' => nil,
                                                                              'developer' => nil, 'team_member' => nil, 'fs_sub_category' => nil, 'fs_item' => nil, 'freshsales_subcategory' => nil,
                                                                              'freshsales_item' => nil, 'bu' => 'Freshdesk', 'freshcaller_sub_category' => nil, 'level_2' => nil, 'cf_item' => nil,
                                                                              'cf_request_for' => nil, 'cf_level_3' => nil, 'phone_number' => nil, 'freshcaller_category' => nil,
                                                                              'freshsales_category' => nil, 'create_a_bug_in_bug_server' => false, 'category' => 'Others',
                                                                              'reuest_type' => 'Technical support question', 'escalation_sent' => 'No', 'second_escalation_email' => 'No',
                                                                              'awaiting_response' => 'No', 'cf_customer_type' => nil, 'level_1' => nil, 'cf_freshchat_appid' => nil,
                                                                              'bug_id' => nil, 'fs_category' => nil, 'cf_app_name' => nil, 'freshservice_teams' => nil,
                                                                              'cf_freshchat_plan' => nil, 'department1' => nil, 'cf_agent_count' => nil, 'cf_account_state' => nil,
                                                                              'cf_mau_count' => nil, 'customer_plan' => nil, 'closure_reason' => nil, 'cf_l2_updated_time' => nil,
                                                                              'cf_region' => nil, 'action_items' => nil, 'cf_l2_ticket_id' => nil, 'cf_state' => nil,
                                                                              'cf_country' => nil, 'downgradedeletion' => nil, 'cf_l2_dev_ticket_id' => nil, 'survey_analysis' => nil,
                                                                              'cf_growthscore_nps' => nil, 'cf_fs_region' => nil, 'cf_freshworks_product' => nil,
                                                                              'cf_fs_customer_plans' => nil, 'cf_fs_mid_market' => nil, 'cf_further_action_required' => nil,
                                                                              'cf_customer_mrr' => nil }, 'created_at' => '2019-05-29T12:08:37Z', 'updated_at' => '2019-05-31T12:10:41Z',
                                'associated_tickets_count' => nil, 'tags' => ['nomrrtkt'], 'internal_agent_id' => nil, 'internal_group_id' => nil }].freeze
  SUPPORT_CONTACTS_RESPONSE_WITHOUT_COMPANY = [{ 'active' => true, 'address' => nil, 'company_id' => nil,
                                                 'description' => nil, 'email' => 'sample@freshdesk.com', 'id' => 28_271_068,
                                                 'job_title' => nil, 'language' => 'en', 'mobile' => nil, 'name' => 'Jeff Brown',
                                                 'phone' => nil, 'time_zone' => 'Chennai', 'twitter_id' => nil,
                                                 'custom_fields' => { 'subscription' => nil, 'community_champion' => nil,
                                                                      'trailblazer' => nil, 'steamroller' => nil, 'community_shaker' => nil,
                                                                      'storyteller' => nil, 'community_wizard' => nil }, 'facebook_id' => nil,
                                                 'created_at' => '2019-01-14T19:38:37Z', 'updated_at' => '2019-05-13T19:20:12Z',
                                                 'unique_external_id' => nil }].freeze

  def teardown
    AwsWrapper::S3Object.unstub(:exists?)
  end
  
  def get_valid_params_for_cancel
    { cancellation_feedback: "Account Cancellation feedback",
      additional_cancellation_feedback: "Additional Info from user"}
  end
  
  def reset_account_subscription_state(state)
    subscription = @account.subscription
    subscription.update_column(:state, state)
    @account.reload
  end
  
  def set_account_cancellation_redis_key
    set_others_redis_key(@account.account_cancellation_request_job_key,100000) unless @account.nil?
  end
  
  def test_cancellation_feedback_presence
    post :cancel, construct_params({})
    assert_response 400
  end
  
  def test_cancellation_feedback_data_type_mismatch
    post :cancel, construct_params({cancellation_feedback: 1.to_i })
    assert_response 400
  end
  
  def test_account_cancellation
    reset_account_subscription_state('trail')
    url = "#{CHARGEBEE_SUBSCRIPTION_BASE_URL}/#{@account.id}"
    stub_request(:get, url).to_return(status: 200, body: chargebee_subscripiton_reponse.to_json, headers: {})
    post :cancel, construct_params(get_valid_params_for_cancel)
    assert_response 204
    reset_account_subscription_state('trail')
  end
  
  def test_account_cancellation_for_paid_accounts
    create_subscription_payment(amount: 40 )
    reset_account_subscription_state('active')
    post :cancel, construct_params(get_valid_params_for_cancel)
    Account.any_instance.stubs(:account_cancellation_requested?).returns(true)
    assert_response 204
    assert_equal true, @account.account_cancellation_requested?
    reset_account_subscription_state('trail')
  ensure
    @account.subscription_payments.destroy_all
    @account.delete_account_cancellation_request_job_key
  end
  
  def test_account_cancellation_state_validation_fail
    reset_account_subscription_state('suspended')
    post :cancel, construct_params(get_valid_params_for_cancel)
    assert_response 403
    match_json({ 'code' => 'account_suspended', 'message' => 'Your account has been suspended.' })
    reset_account_subscription_state('trail')
  end
  
  def test_account_cancellation_request_already_placed
    reset_account_subscription_state('active')
    Account.any_instance.stubs(:account_cancellation_requested?).returns(true)
    post :cancel, construct_params(get_valid_params_for_cancel)
    assert_response 400
    match_json([
      {
        code: 'invalid_value', 
        field: 'account_cancel', 
        message: 'Account Cancellation already requested.'
      }
    ])
  ensure
    @account.delete_account_cancellation_request_job_key if @account
  end

  def test_download_file_to_respond_type_invalid_value_error
    get :download_file, controller_params(  version: 'private',
                                            type: Faker::Lorem.characters(10))
    assert_response 400
    match_json([
      {
        code: 'invalid_value',
        field: 'type',
        message: 'It should be one of these values: \'beacon\''
      }
    ])
  end

  def test_download_file_to_respond_302_for_beacon_report
    AwsWrapper::S3Object.stubs(:exists?).with(
      "#{Account.current.id}/beacon_report/beacon_report.pdf", S3_CONFIG[:bucket]
    ).returns(true)
    AwsWrapper::S3Object.stubs(:url_for).with(
      "#{Account.current.id}/beacon_report/beacon_report.pdf", S3_CONFIG[:bucket],
      {
        expires: Account::FILE_DOWNLOAD_URL_EXPIRY_TIME,
        secure: true
      }
    ).returns('https://dummy.s3.url')
    get :download_file, controller_params(version: 'private', type: 'beacon')
    assert_response 302
    assert response.header['Location'], 'https://dummy.s3.url'
  end

  def test_download_file_to_respond_404_on_file_not_exists
    AwsWrapper::S3Object.stubs(:exists?).with(
      "#{Account.current.id}/beacon_report/beacon_report.pdf", S3_CONFIG[:bucket]).
      returns(false)
    get :download_file, controller_params(version: 'private', type: 'beacon')
    assert_response 404
  end

  def test_unresolved_tickets_count
    contacts_url = "#{PRODUCT_FEEDBACK_CONFIG['feedback_account']}/#{PRODUCT_FEEDBACK_CONFIG['contacts_path']}?email=sample@freshdesk.com"
    stub_request(:get, contacts_url).with(
                  headers:  { 'Accept' => '*/*; q=0.5, application/xml',
                              'Accept-Encoding' => 'gzip, deflate',
                              'User-Agent' => 'Ruby' }
                ).to_return(status: 200, body: SUPPORT_CONTACTS_RESPONSE.to_json, headers: {})
    updated_since_date = (Time.now - 3.month).utc.iso8601
    ticket_url = "#{PRODUCT_FEEDBACK_CONFIG['feedback_account']}/#{PRODUCT_FEEDBACK_CONFIG['tickets_path']}?company_id=854881&per_page=100&updated_since=#{updated_since_date}"
    stub_request(:get, ticket_url).with(
                  headers:  { 'Accept' => '*/*; q=0.5, application/xml',
                              'Accept-Encoding' => 'gzip, deflate',
                              'Authorization'=>'Basic ZHVtbXktYXBpLWtleTo=',
                              'User-Agent' => 'Ruby' }
                ).to_return(status: 200, body: SUPPORT_TICKETS_RESPONSE.to_json, headers: {})
    get :support_tickets, controller_params(version: 'private')
    assert_response 200
    assert_equal JSON.parse(response.body)['unresolved_count'], fetch_unresolved_ticket_count
  end

  def test_unresolved_tickets_count_without_company
    contacts_url = "#{PRODUCT_FEEDBACK_CONFIG['feedback_account']}/#{PRODUCT_FEEDBACK_CONFIG['contacts_path']}?email=sample@freshdesk.com"
    stub_request(:get, contacts_url).with(
                 headers: {  'Accept' => '*/*; q=0.5, application/xml',
                             'Accept-Encoding' => 'gzip, deflate',
                             'User-Agent' => 'Ruby' }
               ).to_return(status: 200, body: SUPPORT_CONTACTS_RESPONSE_WITHOUT_COMPANY.to_json, headers: {})
    updated_since_date = (Time.now - 3.month).utc.iso8601
    ticket_url = "#{PRODUCT_FEEDBACK_CONFIG['feedback_account']}/#{PRODUCT_FEEDBACK_CONFIG['tickets_path']}?requester_id=28271068&per_page=100&updated_since=#{updated_since_date}"
    stub_request(:get, ticket_url).with(
                 headers: {  'Accept' => '*/*; q=0.5, application/xml',
                             'Accept-Encoding' => 'gzip, deflate',
                             'Authorization'=>'Basic ZHVtbXktYXBpLWtleTo=',
                             'User-Agent' => 'Ruby' }
               ).to_return(status: 200, body: SUPPORT_TICKETS_RESPONSE.to_json, headers: {})
    get :support_tickets, controller_params(version: 'private')
    assert_response 200
    assert_equal JSON.parse(response.body)['unresolved_count'], fetch_unresolved_ticket_count
  end

  def test_unresolved_tickets_counts_without_user
    contacts_url = "#{PRODUCT_FEEDBACK_CONFIG['feedback_account']}/#{PRODUCT_FEEDBACK_CONFIG['contacts_path']}?email=sample@freshdesk.com"
    stub_request(:get, contacts_url).with(
                 headers: {  'Accept' => '*/*; q=0.5, application/xml',
                             'Accept-Encoding' => 'gzip, deflate',
                             'User-Agent' => 'Ruby' }
               ).to_return(status: 200, body: '[]', headers: {})
    get :support_tickets, controller_params(version: 'private')
    assert_equal JSON.parse(response.body)['unresolved_count'], 0
  end

  private
  
    def fetch_unresolved_ticket_count
      unresolved_ticket_count = 0
      SUPPORT_TICKETS_RESPONSE.each do |ticket|
        unless ticket['status'] == Helpdesk::Ticketfields::TicketStatus::RESOLVED || ticket['status'] == Helpdesk::Ticketfields::TicketStatus::CLOSED
          unresolved_ticket_count += 1
        end
      end
      unresolved_ticket_count
    end
end
