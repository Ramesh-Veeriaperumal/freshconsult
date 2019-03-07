require './test/test_helper'
require 'ostruct'

class FakeIncomingPhoneNumbers
  def list
    []
  end
end

class FakeTwilioSubAccount
  def status
    "active"
  end

  def incoming_phone_numbers
    FakeIncomingPhoneNumbers.new
  end
end

class FakeTwilioClientAccounts
  def get(obj)
    FakeTwilioSubAccount.new
  end
end

class FakeTwilioClient
  def accounts
    FakeTwilioClientAccounts.new
  end
end

class Channel::Freshcaller::MigrationControllerTest < ActionController::TestCase
  def setup
    super
    @controller.request.env['Authorization'] = "Custom"
    @account = @account || Account.first.make_current
    @user = @user || @account.technicians.first.make_current
    Channel::Freshcaller::MigrationController.any_instance.stubs(:authenticate_jwt_request).returns(@user)
    @freshfone_account = Freshfone::Account.new
    @account.stubs(:freshfone_account).returns(@freshfone_account)
    Account.stubs(:find).returns(@account)
    TwilioMaster.stubs(:client).returns(FakeTwilioClient.new)
    @account.stubs(:freshcaller_account).returns(OpenStruct.new({freshcaller_account_id: @account.id}))
    @account.stubs(:freshfone_credit).returns(OpenStruct.new({available_credit: 0}))
  end

  def teardown
    @account.unstub(:freshfone_credit)
    @account.unstub(:freshcaller_account)
    TwilioMaster.unstub(:client)
    Account.unstub(:find)
    @account.unstub(:freshfone_account)
    Channel::Freshcaller::MigrationController.any_instance.unstub(:authenticate_jwt_request)
  end

  def test_validate
    post :validate, {version: 'private', format: 'json', id: @account.id}
    assert_response 200
  end

  def test_initiate
    post :initiate, {version: 'private', format: 'json', id: @account.id}
    assert_response 200
  end

  def test_cross_verify
    post :cross_verify, {version: 'private', format: 'json', id: @account.id}
    assert_response 200
  end

  def test_fetch_pod_info
    post :fetch_pod_info, {version: 'private', format: 'json', id: @account.id}
    assert_response 200
  end

end
