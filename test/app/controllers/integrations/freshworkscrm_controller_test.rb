# frozen_string_literal: true

require_relative '../../../api/test_helper'
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class Integrations::FreshworkscrmControllerTest < ActionController::TestCase
  include InstalledApplicationsTestHelper

  def setup
    super
    @account = Account.first.make_current || create_test_account
    delete_all_existing_applications
    contact_fields = "{\"first_name\":\"First name\", \"last_name\":\"Last name\", \"sales_accounts\":\"Accounts\", \"emails\":\"Emails\", \"mobile_number\":\"Mobile\", \"work_number\":\"Work\", \"external_id\":\"External ID\", \"owner_id\":\"Sales owner\", \"subscription_status\":\"Subscription status\", \"subscription_types\":\"Subscription types\", \"lifecycle_stage_id\":\"Lifecycle stage\", \"contact_status_id\":\"Status\", \"lost_reason_id\":\"Lost reason\", \"work_email\":\"Work email\", \"tags\":\"Tags\", \"job_title\":\"Job title\", \"time_zone\":\"Time zone\", \"phone_numbers\":\"Other phone numbers\", \"address\":\"Address\", \"city\":\"City\", \"state\":\"State\", \"zipcode\":\"Zipcode\", \"country\":\"Country\", \"facebook\":\"Facebook\", \"twitter\":\"Twitter\", \"linkedin\":\"LinkedIn\", \"territory_id\":\"Territory\", \"lead_source_id\":\"Source\", \"campaign_id\":\"Campaign\", \"medium\":\"Medium\", \"keyword\":\"Keyword\", \"lists\":\"Lists\", \"last_contacted\":\"Last contacted time\", \"last_contacted_mode\":\"Last contacted mode\", \"last_contacted_sales_activity_mode\":\"Last activity type\", \"last_contacted_via_sales_activity\":\"Last activity date\", \"active_sales_sequences\":\"Active sales sequences\", \"completed_sales_sequences\":\"Completed sales sequences\", \"last_seen\":\"Last seen\", \"lead_score\":\"Score\", \"customer_fit\":\"Customer fit\", \"recent_note\":\"Recent note\", \"creater_id\":\"Created by\", \"created_at\":\"Created at\", \"updater_id\":\"Updated by\", \"updated_at\":\"Updated at\", \"web_form_ids\":\"Web forms\", \"last_assigned_at\":\"Last assigned at\", \"display_name\":\"Full name\"}"
    account_fields = "{\"name\":\"Name\", \"website\":\"Website\", \"phone\":\"Phone\", \"owner_id\":\"Sales owner\", \"parent_sales_account_id\":\"Parent account\", \"number_of_employees\":\"Number of employees\", \"annual_revenue\":\"Annual revenue\", \"tags\":\"Tags\", \"industry_type_id\":\"Industry type\", \"business_type_id\":\"Business type\", \"territory_id\":\"Territory\", \"address\":\"Address\", \"city\":\"City\", \"state\":\"State\", \"zipcode\":\"Zipcode\", \"country\":\"Country\", \"facebook\":\"Facebook\", \"twitter\":\"Twitter\", \"linkedin\":\"LinkedIn\", \"last_contacted\":\"Last contacted time\", \"last_contacted_mode\":\"Last contacted mode\", \"last_contacted_sales_activity_mode\":\"Last activity type\", \"last_contacted_via_sales_activity\":\"Last activity date\", \"active_sales_sequences\":\"Active sales sequences\", \"completed_sales_sequences\":\"Completed sales sequences\", \"recent_note\":\"Recent note\", \"creater_id\":\"Created by\", \"created_at\":\"Created at\", \"updater_id\":\"Updated by\", \"updated_at\":\"Updated at\", \"last_assigned_at\":\"Last assigned at\"}"
    deal_fields = "{\"name\":\"Name\", \"amount\":\"Deal value\", \"sales_account_id\":\"Account name\", \"contacts\":\"Related contacts\", \"deal_pipeline_id\":\"Deal pipeline\", \"deal_stage_id\":\"Deal stage\", \"deal_reason_id\":\"Lost reason\", \"closed_date\":\"Closed date\", \"owner_id\":\"Sales owner\", \"tags\":\"Tags\", \"currency_id\":\"Currency\", \"base_currency_amount\":\"Deal value in Base Currency\", \"deal_payment_status_id\":\"Payment status\", \"expected_close\":\"Expected close date\", \"probability\":\"Probability (%)\", \"territory_id\":\"Territory\", \"deal_type_id\":\"Type\", \"lead_source_id\":\"Source\", \"campaign_id\":\"Campaign\", \"last_contacted_sales_activity_mode\":\"Last activity type\", \"last_contacted_via_sales_activity\":\"Last activity date\", \"age\":\"Age (in days)\", \"recent_note\":\"Recent note\", \"active_sales_sequences\":\"Active sales sequences\", \"completed_sales_sequences\":\"Completed sales sequences\", \"creater_id\":\"Created by\", \"created_at\":\"Created at\", \"updater_id\":\"Updated by\", \"updated_at\":\"Updated at\", \"web_form_id\":\"Web form\", \"upcoming_activities_time\":\"Upcoming activities\", \"stage_updated_time\":\"Deal stage updated at\", \"last_assigned_at\":\"Last assigned at\", \"expected_deal_value\":\"Expected deal value\"}"
    contact_mock = Minitest::Mock.new
    contact_mock.expect :body, contact_fields
    contact_mock.expect :status, 200
    account_mock = Minitest::Mock.new
    account_mock.expect :body, account_fields
    account_mock.expect :status, 200
    deal_mock = Minitest::Mock.new
    deal_mock.expect :body, deal_fields
    deal_mock.expect :status, 200
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmAccountResource.any_instance.stubs(:http_get).returns(account_mock)
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource.any_instance.stubs(:http_get).returns(contact_mock)
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmDealResource.any_instance.stubs(:http_get).returns(deal_mock)
  end

  def teardown
    super
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmAccountResource.any_instance.unstub(:http_get)
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmContactResource.any_instance.unstub(:http_get)
    IntegrationServices::Services::Freshworkscrm::FreshworkscrmDealResource.any_instance.unstub(:http_get)
  end

  def test_freshworkscrm_install_from_marketplace
    get :new, format: 'html'
    assert_response 200
  end

  def test_freshworkscrm_update_intial_settings
    post :settings_update, format: 'html', 'configs' => { 'auth_token' => 'abcdjhdjs', 'domain' => 'freshworkscrm', 'ghostvalue' => 'khakdaksdhk' }
    assert_response 200
    assert_not_nil (@account.installed_applications.find { |app| app.application_id == 53 })
  end

  def test_freshworkscrm_edit_exiting_settings
    post :edit, format: 'html'
    assert_response 302
  end

  def test_freshworkscrm_update_after_install
    post :install, format: 'html', 'account_labels' => 'Name', 'contact_labels' => 'Full name', 'deal_labels' => 'Name,Deal value,Deal stage', 'accounts' => ['name'], 'contacts' => ['name'], 'deal_view' => { 'value' => 1 }, 'deals' => ['name', 'amount', 'deal_stage_id']
    assert_response 302
  end

  def test_freshworkscrm_update_existing_settings
    post :update, format: 'html', 'account_labels' => 'Name', 'contact_labels' => 'Full name', 'deal_labels' => 'Name,Deal value,Deal stage', 'accounts' => ['name'], 'contacts' => ['name'], 'deal_view' => { 'value' => 1 }, 'deals' => ['name', 'amount', 'deal_stage_id']
    assert_response 302
  end
end
