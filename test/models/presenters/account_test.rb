require_relative '../test_helper'
require 'faker'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class AccountTest < ActiveSupport::TestCase
  include AccountTestHelper
  
  def test_create
    CentralPublishWorker::AccountWorker.jobs.clear
    create_new_account(Faker::Name.first_name, Faker::Internet.email)
    @account.conversion_metric = ConversionMetric.new(account_id: @account.id,
                                                      landing_url: 'http://freshdesk.com/signup',
                                                      first_referrer: 'http://freshdesk.com/signup',
                                                      first_landing_url: 'http://freshdesk.com/signup',
                                                      country: 'INDIA')
    @account.conversion_metric.save!
    assert_equal 1, CentralPublishWorker::AccountWorker.jobs.size
    payload = @account.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_account_post(@account))
    assoc_payload = @account.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(central_publish_account_association_pattern(@account))
  end

  def test_add_bitmap_feature
    setup
    @account.revoke_feature(:skill_based_round_robin)
    CentralPublishWorker::AccountWorker.jobs.clear
    @account.add_feature(:skill_based_round_robin)
    assert_equal 1, CentralPublishWorker::AccountWorker.jobs.size
    payload = @account.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_account_post(@account))
    job = CentralPublishWorker::AccountWorker.jobs.last
    assert_equal 'account_update', job['args'][0]
    assert_equal({ 'added' => ["skill_based_round_robin"], 'removed' => [] }, job['args'][1]['model_changes']['features'])
  ensure
     @account.revoke_feature(:skill_based_round_robin)
  end
  
  def test_remove_bitmap_feature
    setup
    @account.add_feature(:skill_based_round_robin)
    CentralPublishWorker::AccountWorker.jobs.clear
    @account.revoke_feature(:skill_based_round_robin)
    assert_equal 1, CentralPublishWorker::AccountWorker.jobs.size
    payload = @account.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_account_post(@account))
    job = CentralPublishWorker::AccountWorker.jobs.last
    assert_equal 'account_update', job['args'][0]
    assert_equal({ 'added' => [], 'removed' => ["skill_based_round_robin"] }, job['args'][1]['model_changes']['features'])
  end

  def test_account_publish_for_suspended_account?
    Account.stubs(:current).returns(Account.first || create_test_account)
    Subscription.any_instance.stubs(:suspended?).returns(true)
    pass_value = Account.disallow_payload?('account_destroy')
    assert_equal false, pass_value
    Account.unstub(:current)
    Subscription.any_instance.unstub(:suspended?)
  end

  def test_account_publish_for_suspended_account_fail
    Account.stubs(:current).returns(Account.first || create_test_account)
    Subscription.any_instance.stubs(:suspended?).returns(true)
    pass_value = Account.disallow_payload?('default_value')
    assert_equal true, pass_value
    Account.unstub(:current)
    Subscription.any_instance.unstub(:suspended?)
  end

  def test_account_publish_for_account_configuration_change
    setup
    CentralPublishWorker::AccountWorker.jobs.clear
    current_account_configuration = @account.account_configuration.account_configuration_for_central.stringify_keys
    expected_model_change = { 'account_configuration' => [current_account_configuration.clone, current_account_configuration.clone] }
    expected_model_change['account_configuration'][1].merge!({ 'first_name'=>'Seafarer', 
                                                               'address'=>'SP Infocity', 
                                                               'city'=>'Chennai', 
                                                               'state'=>'Tamil Nadu', 
                                                               'zipcode'=>600042, 
                                                               'country'=> 'India' 
                                                             })

    contact_info = @account.account_configuration.contact_info.clone
    new_contact_info = contact_info.clone
    new_contact_info[:first_name] = 'Seafarer'
    company_info = @account.account_configuration.company_info.clone
    new_company_info = company_info.clone
    new_company_info[:location] = { streetName: 'SP Infocity', city: 'Chennai', state: 'Tamil Nadu', postalCode: 600042, country: 'India' }

    @account.account_configuration.update_attributes!({ contact_info: new_contact_info, company_info: new_company_info })
    assert_equal 1, CentralPublishWorker::AccountWorker.jobs.size
    payload = @account.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_account_post(@account))
    job = CentralPublishWorker::AccountWorker.jobs.last
    assert_equal 'account_update', job['args'][0]
    assert_equal(expected_model_change, job['args'][1]['model_changes'])
  ensure
    @account.account_configuration.update_attributes!({ contact_info: contact_info, company_info: company_info })
  end
end
