require_relative '../test_helper'
require 'faker'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class AccountTest < ActiveSupport::TestCase
  include AccountTestHelper

  def setup
    @account = Account.first || create_new_account
    @account.make_current
  end

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
  ensure
    Account.current.destroy if !Account.current.nil? && Account.current.id != 1 && !Account.current.id.nil?
  end

  def test_add_bitmap_feature
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
    Subscription.any_instance.stubs(:suspended?).returns(true)
    pass_value = Account.disallow_payload?('account_destroy')
    assert_equal false, pass_value
    Subscription.any_instance.unstub(:suspended?)
  end

  def test_account_publish_for_suspended_account_fail
    Subscription.any_instance.stubs(:suspended?).returns(true)
    pass_value = Account.disallow_payload?('default_value')
    assert_equal true, pass_value
    Subscription.any_instance.unstub(:suspended?)
  end

  def test_account_publish_for_account_configuration_change
    AccountConfiguration.any_instance.stubs(:update_billing).returns(true)
    @account.reload
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
    AccountConfiguration.any_instance.unstub(:update_billing)
  end

  def test_account_publish_for_account_additional_settings_portal_languages
    @account.reload
    CentralPublishWorker::AccountWorker.jobs.clear
    account_additional_settings = @account.account_additional_settings
    portal_languages_was = account_additional_settings.portal_languages.presence || []
    expected_model_change = { 'portal_languages' => [portal_languages_was, ['es', 'jp-JP']] }
    account_additional_settings.portal_language_setter(['es', 'jp-JP'])
    account_additional_settings.save!
    assert_equal 1, CentralPublishWorker::AccountWorker.jobs.size
    payload = @account.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_account_post(@account))
    job = CentralPublishWorker::AccountWorker.jobs.last
    assert_equal 'account_update', job['args'][0]
    assert_equal(expected_model_change, job['args'][1]['model_changes'])
  end

  def test_account_publish_for_account_additional_settings_portal_languages_with_help_widget_enabled
    @account.reload
    @account.add_feature(:help_widget)
    CentralPublishWorker::AccountWorker.jobs.clear
    account_additional_settings = @account.account_additional_settings
    expected_model_change = { 'portal_languages' => [account_additional_settings.portal_languages, ['en']] }
    account_additional_settings.portal_language_setter(['en'])
    account_additional_settings.save!
    assert_equal 1, CentralPublishWorker::AccountWorker.jobs.size
    payload = @account.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_account_post(@account))
    job = CentralPublishWorker::AccountWorker.jobs.last
    assert_equal 'account_update', job['args'][0]
    assert_equal(expected_model_change, job['args'][1]['model_changes'])
  ensure
    @account.revoke_feature(:help_widget)
  end

  def test_account_publish_for_account_additional_settings_supported_languages
    # multilingual enabled and hence only supported languages can be changed
    setup_multilingual
    @account.reload
    CentralPublishWorker::AccountWorker.jobs.clear
    account_additional_settings = @account.account_additional_settings
    removed_language = [@account.supported_languages.first]
    expected_model_change = {
      'all_languages' => { 'added' => language_details(account_additional_settings.portal_languages), 'removed' => [] }
    }
    account_additional_settings.supported_language_setter(account_additional_settings.portal_languages)
    account_additional_settings.save!
    assert_equal 1, CentralPublishWorker::AccountWorker.jobs.size
    payload = @account.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_account_post(@account))
    job = CentralPublishWorker::AccountWorker.jobs.last
    assert_equal 'account_update', job['args'][0]
    assert_equal(expected_model_change, job['args'][1]['model_changes'])
  end

  def test_account_publish_for_portal_language
    # multilingual not enabled and hence only primary language can be changed, which is portal language
    @account.reload
    Account.any_instance.stubs(:multilingual?).returns(false)
    account_additional_settings = @account.account_additional_settings
    account_additional_settings.supported_language_setter([])
    account_additional_settings.portal_language_setter([])
    account_additional_settings.save!
    old_primary_lang = @account.main_portal.language
    CentralPublishWorker::AccountWorker.jobs.clear
    expected_model_change = { 'portal_languages' => [['en'], []], 'all_languages' => { 'added' => [], 'removed' => language_details(['en']) }}
    @account.main_portal.language = 'es'
    @account.save!
    payload = @account.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_account_post(@account))
    job = CentralPublishWorker::AccountWorker.jobs.last
    assert_equal 'account_update', job['args'][0]
    assert_equal(expected_model_change, job['args'][1]['model_changes'])
  ensure
    Account.any_instance.unstub(:multilingual?)
  end

  def test_publish_for_rts_info
    CentralPublishWorker::AccountWorker.jobs.clear
    @account.reload
    Account.current.stubs(:agent_collision_revamp_enabled?).returns(true)
    acc_additional_settings = @account.account_additional_settings
    acc_additional_settings.additional_settings[:rts_account_id] = Faker::Lorem.characters(6)
    acc_additional_settings.secret_keys[:rts_account_secret] = EncryptorDecryptor.new(RTSConfig['db_cipher_key']).encrypt(Faker::Lorem.characters(6))
    acc_additional_settings.save
    assert_equal 1, CentralPublishWorker::AccountWorker.jobs.size
    payload = @account.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_rts_info(@account))
    job = CentralPublishWorker::AccountWorker.jobs.last
    assert_equal 'account_update', job['args'][0]
  ensure
    @account.rollback(:agent_collision_revamp)
  end
end
