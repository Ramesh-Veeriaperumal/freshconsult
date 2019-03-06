require_relative '../../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'ticket_fields_test_helper.rb')
class TicketStatusTest < ActiveSupport::TestCase
  include TicketFieldsTestHelper

  def setup
    super
    @account = @account.make_current
    @account.launch(:ticket_fields_central_publish)
  end

  def teardown
    @account.rollback(:ticket_fields_central_publish)
    Account.unstub(:current)
  end

  def custom_dropdown_picklist_values_launch_party_enabled
    CentralPublishWorker::TicketFieldWorker.jobs.clear
    create_custom_field_dropdown(Faker::Lorem.characters(10), [Faker::Lorem.characters(10)])
    assert_equal 1, CentralPublishWorker::TicketFieldWorker.jobs.size
  end

  def test_custom_dropdown_picklist_values_create
    CentralPublishWorker::TicketFieldWorker.jobs.clear
    picklist_value = create_custom_field_dropdown(Faker::Lorem.characters(10), [Faker::Lorem.characters(10)]).picklist_values.last
    assert_equal 2, CentralPublishWorker::TicketFieldWorker.jobs.size
    payload = picklist_value.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_picklist_pattern(picklist_value))
  end

  def test_custom_dropdown_picklist_values_update
    choices = [Faker::Lorem.characters(10)]
    picklist_value = create_custom_field_dropdown(Faker::Lorem.characters(10), choices).picklist_values.last
    new_choice_value = Faker::Lorem.characters(10)
    CentralPublishWorker::TicketFieldWorker.jobs.clear
    picklist_value.update_attributes(value: new_choice_value)
    assert_equal 1, CentralPublishWorker::TicketFieldWorker.jobs.size
    payload = picklist_value.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_picklist_pattern(picklist_value))
    job = CentralPublishWorker::TicketFieldWorker.jobs.last
    assert_equal 'picklist_value_update', job['args'][0]
    assert_equal(model_changes_picklist_values(choices.last, new_choice_value), job['args'][1]['model_changes'])
  end

  def test_custom_dropdown_picklist_values_destroy
    picklist_value = create_custom_field_dropdown(Faker::Lorem.characters(10), [Faker::Lorem.characters(10)]).picklist_values.last
    pattern = central_publish_picklist_destroy_pattern(picklist_value)
    CentralPublishWorker::TicketFieldWorker.jobs.clear
    picklist_value.destroy
    assert_equal 1, CentralPublishWorker::TicketFieldWorker.jobs.size
    job = CentralPublishWorker::TicketFieldWorker.jobs.last
    assert_equal 'picklist_value_destroy', job['args'][0]
    assert_equal({}, job['args'][1]['model_changes'])
    job['args'][1]['model_properties'].must_match_json_expression(pattern)
  end
end
