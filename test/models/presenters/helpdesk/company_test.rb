require_relative '../../test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
['companies_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
['company_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['note_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class CompanyTest < ActiveSupport::TestCase
  include CompaniesTestHelper
  include CompanyFieldsTestHelper

  CUSTOM_FIELDS = %w(number checkbox decimal text paragraph dropdown country state city date)
  DROPDOWN_CHOICES = ['Happy work environment', 'Team work', 'speak up']

  def setup
    super
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account.subscription.state = 'active'
    @account.subscription.save
    @account.launch(:company_central_publish)
    @account.company_form.company_fields_from_cache
    @@before_all_run = true
  end	

  def create_company(options = {})
    company = @account.companies.find_by_name(options[:name])
    return company if company
    name = options[:name] || Faker::Name.name
    company = FactoryGirl.build(:company, name: name)
    company.account_id = @account.id
    company.avatar = options[:avatar] if options[:avatar] 
    company.domains = options[:domains].join(',') if options[:domains].present?
    company.health_score = options[:health_score] if options[:health_score]
    company.account_tier = options[:account_tier] if options[:account_tier]
    company.industry = options[:industry] if options[:industry]
    company.renewal_date = options[:renewal_date] if options[:renewal_date]
    company.save!
    company
  end

  def company_params_hash(params = {})
    description = params[:description] || Faker::Lorem.paragraph
    custom_field = params[:custom_field] || { "test_custom_text_#{@account.id}" => 'Sample Text' }
    params_hash = { :customers => {
      :name => params[:name] || Faker::Lorem.characters(5),
      :account_id => params[:account_id] || Faker::Number.number(1),
      :description => description,
      :sla_policy_id => params[:sla_policy_id] || Faker::Number.number(1),
      :note => params[:note] || Faker::Lorem.characters(5),
      :domains => params[:domains] || Faker::Lorem.characters(5),
      :delta => params[:delta] || Faker::Number.number(1),
      :import_id => params[:import_id] || Faker::Number.number(1)
      } }
  end

  def company_destroy_pattern(expected_output = {}, company)
  {
    id: company.id,
    account_id: company.account_id,
    name: company.name
  }
  end

  def company_field(name)
    company_field = CompanyField.new
    company_field.name = name
    company_field.field_type = 'custom_text'
    company_field
  end

  def test_central_publish_with_launch_party_enabled
    @account.launch(:company_central_publish)
    CentralPublishWorker::CompanyWorker.jobs.clear
    company = create_company
    assert_equal 1, CentralPublishWorker::CompanyWorker.jobs.size
  end

  def test_central_publish_payload
    company_field = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'Company text', name: 'cf_company_text', field_options: { 'widget_position' => 12 }))
    company = create_company
    payload = company.central_publish_payload.to_json
    payload.must_match_json_expression(company_payload_pattern(company))
  end

  def test_central_publish_payload_without_custom_fields
    @account.reload
    company = create_company
    payload = company.central_publish_payload.to_json
    payload.must_match_json_expression(company_payload_pattern(company))
  end

  def test_company_central_publish_update_action
    company = create_company
    description_ori = company.description
    CentralPublishWorker::CompanyWorker.jobs.clear
    company.reload
    company.update_attributes(description: 'happy environment')
    payload = company.central_publish_payload.to_json
    payload.must_match_json_expression(company_payload_pattern(company))
    assert_equal 1, CentralPublishWorker::CompanyWorker.jobs.size
    job = CentralPublishWorker::CompanyWorker.jobs.last
    assert_equal 'company_update', job['args'][0]
    assert_equal({ 'description' => [description_ori, company.description], 'account_id' => [0, @account.id], 'company_id' => [nil, company.id], 'company_form_id' => [nil, @account.id] }, job['args'][1]['model_changes'])
  end

  def test_central_publish_custom_fields_update
    company_field = create_company_field(company_params(type: 'text', field_type: 'custom_text', label: 'Company text', name: 'cf_company_text', field_options: { 'widget_position' => 12 }))
    column_name = company_field.name
    company = create_company
    CentralPublishWorker::CompanyWorker.jobs.clear
    company.reload
    company.update_attributes(custom_field: { cf_company_text: 'hello' })
    payload = company.central_publish_payload.to_json
    payload.must_match_json_expression(company_payload_pattern(company))
    assert_equal 1, CentralPublishWorker::CompanyWorker.jobs.size
    job = CentralPublishWorker::CompanyWorker.jobs.last
    assert_equal 'company_update', job['args'][0]
    assert_equal({ 'account_id' => [0, @account.id], 'company_id' => [nil, company.id], 'company_form_id' => [nil, @account.id], column_name => [nil, 'hello'] }, job['args'][1]['model_changes'])
  end

  def test_central_publish_company_destroy
    company = create_company
    pattern_to_match = company_destroy_pattern(company)
    CentralPublishWorker::CompanyWorker.jobs.clear
    company = @account.companies.find(company.id)
    company.destroy
    assert_equal 1, CentralPublishWorker::CompanyWorker.jobs.size
    job = CentralPublishWorker::CompanyWorker.jobs.last
    assert_equal 'company_destroy', job['args'][0]
    assert_equal({}, job['args'][1]['model_changes'])
    job['args'][1]['model_properties'].must_match_json_expression(pattern_to_match)
  end

  def test_company_central_publish_for_suspended_accounts
    @account.subscription.state = 'suspended'
    @account.subscription.save
    CentralPublishWorker::CompanyWorker.jobs.clear
    company = create_company
    assert_equal 0, CentralPublishWorker::CompanyWorker.jobs.size
  ensure
    @account.subscription.state = 'active'
    @account.subscription.save
  end
end
