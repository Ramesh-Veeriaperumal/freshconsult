require_relative '../../test_helper'

class TimeSheetTest < ActiveSupport::TestCase
  include TicketsTestHelper
  include TimeSheetsTestHelper

  class << self
    attr_accessor :before_all_run
  end

  def setup
    super
    before_all
  end

  @before_all_run = false

  def before_all
    return if self.class.before_all_run
    Account.current.launch :time_sheets_central_publish
    self.class.before_all_run = true
  end

  def test_central_publish_with_launch_party_disabled
    Account.current.rollback :time_sheets_central_publish
    ticket = create_ticket(ticket_params_hash)
    ticket.reload
    CentralPublisher::Worker.jobs.clear
    time_sheet = ticket.time_sheets.new(time_sheet_params_hash)
    time_sheet.save
    assert_not_equal 'time_sheet_create', CentralPublisher::Worker.jobs.last['args'][0]
  ensure
    Account.current.launch :time_sheets_central_publish
  end

  def test_central_publish_time_sheet_create_and_user_association
    Account.current.reload
    ticket = create_ticket(ticket_params_hash)
    ticket.reload
    CentralPublisher::Worker.jobs.clear
    time_sheet = ticket.time_sheets.new(time_sheet_params_hash)
    time_sheet.save
    assert_equal 'time_sheet_create', CentralPublisher::Worker.jobs.last['args'][0]
    time_sheet.reload
    payload = time_sheet.central_publish_payload.to_json
    payload.must_match_json_expression(cp_time_sheet_model_properties(time_sheet))
    assoc_payload = time_sheet.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(cp_assoc_time_sheet_pattern(time_sheet))
  end

  def test_central_publish_time_sheet_update
    ticket = create_ticket(ticket_params_hash)
    ticket.reload
    time_sheet = ticket.time_sheets.new(time_sheet_params_hash)
    time_sheet.save
    time_sheet.reload
    CentralPublisher::Worker.jobs.clear
    old_value = time_sheet.time_spent
    new_value = Faker::Number.number(4).to_i
    time_sheet.update_attributes(time_spent: new_value)
    assert_equal 1, CentralPublisher::Worker.jobs.size
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'time_sheet_update', job['args'][0]
    assert_equal({ 'time_spent': [old_value, new_value] }, job['args'][1]['model_changes'].symbolize_keys)
  end

  def test_central_publish_time_sheet_destroy
    ticket = create_ticket(ticket_params_hash)
    ticket.reload
    time_sheet = ticket.time_sheets.new(time_sheet_params_hash)
    time_sheet.save
    time_sheet.reload
    pattern_to_match = cp_time_sheet_destroy_pattern(time_sheet)
    CentralPublisher::Worker.jobs.clear
    time_sheet.destroy
    assert_equal 1, CentralPublisher::Worker.jobs.size
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'time_sheet_destroy', job['args'][0]
    assert_equal({}, job['args'][1]['model_changes'])
    job['args'][1]['model_properties'].must_match_json_expression(pattern_to_match)
  end
end
