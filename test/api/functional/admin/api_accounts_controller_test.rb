require_relative '../../test_helper.rb'
require 'sidekiq/testing'
require 'webmock/minitest'
Sidekiq::Testing.fake!

class Admin::ApiAccountsControllerTest < ActionController::TestCase
  include ApiAccountHelper
  include Redis::OthersRedis
  CHARGEBEE_SUBSCRIPTION_BASE_URL = 'https://freshpo-test.chargebee.com/api/v1/subscriptions'.freeze
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
    {
      cancellation_feedback: 'Account Cancellation feedback',
      additional_cancellation_feedback: 'Additional Info from user'
    }
  end

  def reset_account_subscription_state(state)
    subscription = @account.subscription
    subscription.update_column(:state, state)
    @account.reload
  end

  def set_account_cancellation_redis_key
    set_others_redis_key(@account.account_cancellation_request_job_key, 100_000) unless @account.nil?
  end

  def test_cancellation_feedback_presence
    put :cancel, construct_params({})
    assert_response 400
  end

  def test_cancellation_feedback_data_type_mismatch
    put :cancel, construct_params(cancellation_feedback: 1.to_i)
    assert_response 400
  end

  def test_account_cancellation
    reset_account_subscription_state('trail')
    url = "#{CHARGEBEE_SUBSCRIPTION_BASE_URL}/#{@account.id}"
    stub_request(:get, url).to_return(status: 200, body: chargebee_subscripiton_reponse.to_json, headers: {})
    put :cancel, construct_params(get_valid_params_for_cancel)
    assert_response 204
    reset_account_subscription_state('trail')
  end

  def test_account_cancellation_for_paid_accounts
    create_subscription_payment(amount: 40)
    reset_account_subscription_state('active')
    put :cancel, construct_params(get_valid_params_for_cancel)
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
    put :cancel, construct_params(get_valid_params_for_cancel)
    assert_response 403
    match_json('code' => 'account_suspended', 'message' => 'Your account has been suspended.')
    reset_account_subscription_state('trail')
  end

  def test_account_cancellation_request_already_placed
    reset_account_subscription_state('active')
    Account.any_instance.stubs(:account_cancellation_requested?).returns(true)
    put :cancel, construct_params(get_valid_params_for_cancel)
    assert_response 204
  ensure
    @account.delete_account_cancellation_request_job_key if @account
  end

  def test_account_cancellation_with_downgrade_policy_enabled
    reset_account_subscription_state('active')
    @account.launch(:downgrade_policy)
    subscription_response = chargebee_subscripiton_reponse
    subscription_response[:subscription][:status] = 'active'
    url = "#{CHARGEBEE_SUBSCRIPTION_BASE_URL}/#{@account.id}"
    stub_request(:get, url).to_return(status: 200, body: subscription_response.to_json, headers: {})
    ChargeBee::Subscription.stubs(:cancel).returns(true)
    put :cancel, construct_params(get_valid_params_for_cancel)
    assert_response 204
    assert @account.account_cancellation_requested?
  ensure
    reset_account_subscription_state('trail')
    @account.delete_account_cancellation_requested_time_key
    ChargeBee::Subscription.unstub(:cancel)
    @account.rollback(:downgrade_policy)
  end

  def test_download_file_to_respond_type_invalid_value_error
    get :download_file, controller_params(version: 'private', type: Faker::Lorem.characters(10))
    assert_response 400
    match_json([{ code: 'invalid_value', field: 'type', message: 'It should be one of these values: \'beacon\'' }])
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
    stub_request(:get, contacts_path).to_return(body: SUPPORT_CONTACTS_RESPONSE.to_json, status: 200)
    stub_request(:get, tickets_path).to_return(body: SUPPORT_TICKETS_RESPONSE.to_json, status: 200)
    get :support_tickets, controller_params(version: 'private')
    assert_response 200
    assert_equal JSON.parse(response.body)['unresolved_count'], fetch_unresolved_ticket_count
  end

  def test_unresolved_tickets_count_without_company
    stub_request(:get, contacts_path).to_return(body: SUPPORT_CONTACTS_RESPONSE_WITHOUT_COMPANY.to_json, status: 200)
    stub_request(:get, tickets_path).to_return(body: SUPPORT_TICKETS_RESPONSE.to_json, status: 200)
    get :support_tickets, controller_params(version: 'private')
    assert_response 200
    assert_equal JSON.parse(response.body)['unresolved_count'], fetch_unresolved_ticket_count
  end

  def test_unresolved_tickets_counts_without_user
    stub_request(:get, contacts_path).to_return(body: '[]', status: 200)
    get :support_tickets, controller_params(version: 'private')
    assert_equal JSON.parse(response.body)['unresolved_count'], 0
  end

  def test_unresolved_tickets_count_with_random_email
    fn = Faker::Name.first_name
    ln = Faker::Name.last_name
    User.any_instance.stubs(:email).returns("#{fn}+1+.#{ln}@freshdesk.com")
    contacts_url = "#{PRODUCT_FEEDBACK_CONFIG['feedback_account']}/#{PRODUCT_FEEDBACK_CONFIG['contacts_path']}?email=#{fn}+1+.#{ln}@freshdesk.com"
    stub_request(:get, contacts_url).to_raise(StandardError)
    get :support_tickets, controller_params(version: 'private')
    assert_equal JSON.parse(response.body)['unresolved_count'], 0 
  end

  def test_reactivate_cancelled_account
    @account.launch(:downgrade_policy)
    set_others_redis_key(@account.account_cancellation_request_time_key, Time.now, nil)
    ChargeBee::Subscription.stubs(:remove_scheduled_cancellation).returns(true)
    delete :reactivate, controller_params(version: 'private')
    assert_response 204
  ensure
    ChargeBee::Subscription.unstub(:remove_scheduled_cancellation)
    remove_others_redis_key @account.account_cancellation_request_time_key
    @account.rollback(:downgrade_policy)
  end

  def test_reactivate_active_account
    @account.launch(:downgrade_policy)
    remove_others_redis_key @account.account_cancellation_request_time_key
    delete :reactivate, controller_params(version: 'private')
    assert_response 404
  ensure
    @account.rollback(:downgrade_policy)
  end

  def test_reactivate_on_chargebee_exception_account
    @account.launch(:downgrade_policy)
    set_others_redis_key(@account.account_cancellation_request_time_key, Time.now, nil)
    ChargeBee::Subscription.stubs(:remove_scheduled_cancellation).raises(StandardError, 'Chargebee Exception')
    delete :reactivate, controller_params(version: 'private')
    assert_response 404
  ensure
    ChargeBee::Subscription.unstub(:remove_scheduled_cancellation)
    remove_others_redis_key @account.account_cancellation_request_time_key
    @account.rollback(:downgrade_policy)
  end

  def test_reactivate_unscheduled_account_cancellation
    @account.rollback(:downgrade_policy)
    delete :reactivate, controller_params(version: 'private')
    assert_response 404
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

    def contacts_path
      user_email = Faker::Internet.email
      User.any_instance.stubs(:email).returns(user_email)
      "#{PRODUCT_FEEDBACK_CONFIG['feedback_account']}/#{PRODUCT_FEEDBACK_CONFIG['contacts_path']}?email=#{user_email}"
    end

    def tickets_path
      %r{^#{PRODUCT_FEEDBACK_CONFIG['feedback_account']}/#{PRODUCT_FEEDBACK_CONFIG['tickets_path']}.*?$}
    end
end
