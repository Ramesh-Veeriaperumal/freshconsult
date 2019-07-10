require_relative '../../../api/test_helper'

class PartnerAdmin::AffiliatesControllerTest < ActionController::TestCase

  def setup
    user_name = AppConfig['reseller_portal']['user_name']
    password = AppConfig['reseller_portal']['password']
    shared_secret = AppConfig['reseller_portal']['shared_secret']
    timestamp = Time.now.getutc.to_i.to_s
    digest  = OpenSSL::Digest.new('MD5')
    hash = OpenSSL::HMAC.hexdigest(digest, shared_secret, user_name+timestamp)
    @auth_params = { :hash => hash, :timestamp => timestamp }
    PartnerSubdomains.stubs(:include?).returns(true)
    SubscriptionAffiliate.stubs(:find_by_token).returns(SubscriptionAffiliate.create(name: 'ShareASale', rate: 0.2000, token: 148))
  end

  def teardown
    SubscriptionAffiliate.unstub(:find_by_token)
    PartnerSubdomains.unstub(:include?)
  end

  def test_edit_affiliate_with_valid_params
    params_hash = { affiliate: { id: 1, name: 'ShareASale', rate: 0.2500 }, token: '148' }
    @controller.stubs(:authenticate_using_basic_auth).returns(200)
    post :edit_affiliate, params_hash.merge!(@auth_params)
    assert_response 200
  end

  def test_edit_affiliate_with_invalid_params
    params_hash = { affiliate: { id: 1, name: 'ShareASale', rate: 0.2500, dummy: 'dummy', invalid: 123 }, token: '148' }
    @controller.stubs(:authenticate_using_basic_auth).returns(200)
    post :edit_affiliate, params_hash.merge!(@auth_params)
    assert_response 400
  end

end
