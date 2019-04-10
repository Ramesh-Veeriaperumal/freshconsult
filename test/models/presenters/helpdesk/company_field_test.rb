require_relative '../../test_helper'
['company_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
class CompanyFieldTest < ActiveSupport::TestCase
  include CompanyFieldsTestHelper

  def setup
    super
    @account = @account.make_current
    @account.launch(:company_field_central_publish)
    CentralPublishWorker::CompanyFieldWorker.jobs.clear
  end

  def teardown
    @account.rollback(:company_field_central_publish)
    Account.unstub(:current)
  end

  def create_company_custom_field(field_type)
    cf_param = company_params(type: field_type, field_type: "custom_#{field_type}", label: Faker::Lorem.characters(10))
    create_custom_company_field(cf_param)
  end

  def test_create_company_field_for_text_with_launchparty_enabled
    create_company_custom_field('text')
    assert_equal 1, CentralPublishWorker::CompanyFieldWorker.jobs.size
  end

  def test_create_company_field_for_text_with_launchparty_disabled
    @account.rollback(:company_field_central_publish)
    create_company_custom_field('text')
    assert_equal 0, CentralPublishWorker::CompanyFieldWorker.jobs.size
  ensure
    @account.launch(:company_field_central_publish)
  end

  def test_create_company_field_for_paragraph
    custom_field = create_company_custom_field('paragraph')
    assert_equal 1, CentralPublishWorker::CompanyFieldWorker.jobs.size
    payload = custom_field.central_publish_payload.to_json
    payload.must_match_json_expression(company_field_publish_pattern(custom_field))
  end

  def test_create_company_field_for_checkbox
    custom_field = create_company_custom_field('checkbox')
    assert_equal 1, CentralPublishWorker::CompanyFieldWorker.jobs.size
    payload = custom_field.central_publish_payload.to_json
    payload.must_match_json_expression(company_field_publish_pattern(custom_field))
  end

  def test_create_company_field_for_number
    custom_field = create_company_custom_field('number')
    assert_equal 1, CentralPublishWorker::CompanyFieldWorker.jobs.size
    payload = custom_field.central_publish_payload.to_json
    payload.must_match_json_expression(company_field_publish_pattern(custom_field))
  end

  def test_create_company_field_for_dropdown
    field_type = 'dropdown'
    choices = [{ value: Faker::Lorem.characters(10), position: 1 }, { value: Faker::Lorem.characters(10), position: 2 }]
    cf_param = company_params(type: field_type, field_type: "custom_#{field_type}", label: Faker::Lorem.characters(10), custom_field_choices_attributes: choices)
    custom_field = create_custom_company_field(cf_param)
    assert_equal 3, CentralPublishWorker::CompanyFieldWorker.jobs.size
    payload = custom_field.central_publish_payload.to_json
    payload.must_match_json_expression(company_field_publish_pattern(custom_field))
  end

  def test_update_company_field_for_number
    custom_field = create_company_custom_field('number')
    CentralPublishWorker::CompanyFieldWorker.jobs.clear
    custom_field.update_attributes(label: Faker::Lorem.characters(10))
    assert_equal 1, CentralPublishWorker::CompanyFieldWorker.jobs.size
    payload = custom_field.central_publish_payload.to_json
    payload.must_match_json_expression(company_field_publish_pattern(custom_field))
  end

  def test_destroy_company_field_for_dropdown
    field_type = 'dropdown'
    choices = [{ value: Faker::Lorem.characters(10), position: 1 }, { value: Faker::Lorem.characters(10), position: 2 }]
    cf_param = company_params(type: field_type, field_type: "custom_#{field_type}", label: Faker::Lorem.characters(10), custom_field_choices_attributes: choices)
    custom_field = create_custom_company_field(cf_param)
    CentralPublishWorker::CompanyFieldWorker.jobs.clear
    custom_field.destroy
    assert_equal 3, CentralPublishWorker::CompanyFieldWorker.jobs.size
  end
end
