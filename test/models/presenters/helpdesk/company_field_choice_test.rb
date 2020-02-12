require_relative '../../test_helper'
['company_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
class CompanyFieldChoiceTest < ActiveSupport::TestCase
  include CompanyFieldsTestHelper

  def setup
    super
    @account = @account.make_current
    CentralPublishWorker::CompanyFieldWorker.jobs.clear
  end

  def teardown
    Account.unstub(:current)
  end

  def create_custom_company_field_choice(field_type, choices)
    cf_param = company_params(type: field_type, field_type: "custom_#{field_type}", label: Faker::Lorem.characters(10), custom_field_choices_attributes: choices)
    custom_field = create_custom_company_field(cf_param)
    @account.company_field_choices.where(company_field_id: custom_field.id).last
  end

  def test_create_contact_field_choice_for_dropdown
    choices = [{ value: Faker::Lorem.characters(10), position: 1 }, { value: Faker::Lorem.characters(10), position: 2 }]
    custom_field_choice = create_custom_company_field_choice('dropdown', choices)
    assert_equal 3, CentralPublishWorker::CompanyFieldWorker.jobs.size
    payload = custom_field_choice.central_publish_payload.to_json
    payload.must_match_json_expression(company_field_choice_publish_pattern(custom_field_choice))
  end

  def test_update_contact_field_choice_for_dropdown
    choices = [{ value: Faker::Lorem.characters(10), position: 1 }]
    new_choice_value = Faker::Lorem.characters(10)
    custom_field_choice = create_custom_company_field_choice('dropdown', choices)
    CentralPublishWorker::CompanyFieldWorker.jobs.clear
    custom_field_choice.update_attributes(value: new_choice_value)
    assert_equal 1, CentralPublishWorker::CompanyFieldWorker.jobs.size
    payload = custom_field_choice.central_publish_payload.to_json
    payload.must_match_json_expression(company_field_choice_publish_pattern(custom_field_choice))
    job = CentralPublishWorker::CompanyFieldWorker.jobs.last
    assert_equal 'company_field_choice_update', job['args'][0]
    assert_equal(model_changes_company_field_choice(choices.last[:value], new_choice_value), job['args'][1]['model_changes'])
  end

  def test_destroy_company_field_choice_for_dropdown
    choices = [{ value: Faker::Lorem.characters(10), position: 1 }]
    custom_field_choice = create_custom_company_field_choice('dropdown', choices)
    pattern = central_publish_company_field_choice_destroy_pattern(custom_field_choice)
    CentralPublishWorker::CompanyFieldWorker.jobs.clear
    custom_field_choice.destroy
    assert_equal 1, CentralPublishWorker::CompanyFieldWorker.jobs.size
    job = CentralPublishWorker::CompanyFieldWorker.jobs.last
    assert_equal 'company_field_choice_destroy', job['args'][0]
    assert_equal({}, job['args'][1]['model_changes'])
    job['args'][1]['model_properties'].must_match_json_expression(pattern)
  end
end
