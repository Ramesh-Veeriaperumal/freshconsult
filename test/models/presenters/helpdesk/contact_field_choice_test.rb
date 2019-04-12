require_relative '../../test_helper'
['contact_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
class ContactFieldChoiceTest < ActiveSupport::TestCase
  include ContactFieldsTestHelper

  def setup
    super
    @account = @account.make_current
    @account.launch(:contact_field_central_publish)
    CentralPublishWorker::ContactFieldWorker.jobs.clear
  end

  def teardown
    @account.rollback(:contact_field_central_publish)
    Account.unstub(:current)
  end

  def create_custom_contact_field_choice(field_type, choices)
    cf_param = cf_params(type: field_type, field_type: "custom_#{field_type}", label: Faker::Lorem.characters(10), editable_in_signup: 'true', custom_field_choices_attributes: choices)
    custom_field = create_custom_contact_field(cf_param)
    @account.contact_field_choices.where(contact_field_id: custom_field.id).last
  end

  def test_create_contact_field_choice_for_dropdown
    choices = [{ value: Faker::Lorem.characters(10), position: 1 }]
    custom_field_choice = create_custom_contact_field_choice('dropdown', choices)
    assert_equal 2, CentralPublishWorker::ContactFieldWorker.jobs.size
    payload = custom_field_choice.central_publish_payload.to_json
    payload.must_match_json_expression(contact_field_choice_publish_pattern(custom_field_choice))
  end

  def test_update_contact_field_choice_for_dropdown
    choices = [{ value: Faker::Lorem.characters(10), position: 1 }]
    custom_field_choice = create_custom_contact_field_choice('dropdown', choices)
    new_choice_value = Faker::Lorem.characters(10)
    CentralPublishWorker::ContactFieldWorker.jobs.clear
    custom_field_choice.update_attributes(value: new_choice_value)
    assert_equal 1, CentralPublishWorker::ContactFieldWorker.jobs.size
    payload = custom_field_choice.central_publish_payload.to_json
    payload.must_match_json_expression(contact_field_choice_publish_pattern(custom_field_choice))
    job = CentralPublishWorker::ContactFieldWorker.jobs.last
    assert_equal 'contact_field_choice_update', job['args'][0]
    assert_equal(model_changes_contact_field_choice(choices.last[:value], new_choice_value), job['args'][1]['model_changes'])
  end

  def test_destroy_contact_field_choice_for_dropdown
    choices = [{ value: Faker::Lorem.characters(10), position: 1 }]
    custom_field_choice = create_custom_contact_field_choice('dropdown', choices)
    pattern = central_publish_contact_field_choice_destroy_pattern(custom_field_choice)
    CentralPublishWorker::ContactFieldWorker.jobs.clear
    custom_field_choice.destroy
    assert_equal 1, CentralPublishWorker::ContactFieldWorker.jobs.size
    job = CentralPublishWorker::ContactFieldWorker.jobs.last
    assert_equal 'contact_field_choice_destroy', job['args'][0]
    assert_equal({}, job['args'][1]['model_changes'])
    job['args'][1]['model_properties'].must_match_json_expression(pattern)
  end
end
