require_relative '../../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'ticket_fields_test_helper.rb')
class TicketStatusTest < ActiveSupport::TestCase
  include TicketFieldsTestHelper

  def setup
    super
    @account = @account.make_current
  end

  def teardown
    Account.unstub(:current)
  end

  def test_ticket_status_with_launch_party_enabled
    CentralPublishWorker::TicketFieldWorker.jobs.clear
    create_custom_status(Faker::Lorem.characters(10))
    assert_equal 1, CentralPublishWorker::TicketFieldWorker.jobs.size
  end

  def test_ticket_status_create_central_publish_payload
    CentralPublishWorker::TicketFieldWorker.jobs.clear
    status = create_custom_status(Faker::Lorem.characters(10))
    assert_equal 1, CentralPublishWorker::TicketFieldWorker.jobs.size
    payload = status.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_ticket_status_pattern(status))
  end

  def test_ticket_status_update_central_publish_payload
    status_name = Faker::Lorem.characters(10)
    status = create_custom_status(status_name)
    CentralPublishWorker::TicketFieldWorker.jobs.clear
    status.update_attributes(name: Faker::Lorem.characters(10))
    assert_equal 1, CentralPublishWorker::TicketFieldWorker.jobs.size
    payload = status.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_ticket_status_pattern(status))
    job = CentralPublishWorker::TicketFieldWorker.jobs.last
    assert_equal 'ticket_status_update', job['args'][0]
    assert_equal(model_changes_ticket_status(status_name, status.name), job['args'][1]['model_changes'])
  end

end
