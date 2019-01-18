require_relative '../../test_helper.rb'
require 'sidekiq/testing'
require 'webmock/minitest'
Sidekiq::Testing.fake!

class Admin::ApiAccountsControllerTest < ActionController::TestCase
  include ApiAccountHelper
  include Redis::OthersRedis
  CHARGEBEE_SUBSCRIPTION_BASE_URL = "https://freshpo-test.chargebee.com/api/v1/subscriptions"

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
    set_account_cancellation_redis_key
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
end
