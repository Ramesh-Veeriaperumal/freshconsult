require_relative '../../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'ticket_fields_test_helper.rb')
class TicketSourceTest < ActiveSupport::TestCase
  include TicketFieldsTestHelper

  def setup
    super
    @account = @account.make_current
  end

  def teardown
    Account.unstub(:current)
  end

  def test_ticket_source_create_central_publish_payload
    CentralPublishWorker::TicketFieldWorker.jobs.clear
    source = create_custom_source
    assert_equal 1, CentralPublishWorker::TicketFieldWorker.jobs.size
    payload = source.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_ticket_source_pattern(source))
  end

  def test_ticket_source_update_central_publish_payload
    source = create_custom_source
    CentralPublishWorker::TicketFieldWorker.jobs.clear
    source_name = Faker::Lorem.characters(10)
    source.update_attributes(name: source_name)
    assert_equal 1, CentralPublishWorker::TicketFieldWorker.jobs.size
    updated_source = Helpdesk::Source.find(source.id)
    assert_equal source_name, updated_source.name
    payload = updated_source.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_ticket_source_pattern(updated_source))
    job = CentralPublishWorker::TicketFieldWorker.jobs.last
    assert_equal 'ticket_source_update', job['args'][0]
  end
end
