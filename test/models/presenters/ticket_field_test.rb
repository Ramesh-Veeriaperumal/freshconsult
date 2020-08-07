require_relative '../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'ticket_fields_test_helper.rb')

class TicketFieldTest < ActiveSupport::TestCase

  include TicketFieldsTestHelper
  
  CUSTOM_FIELDS = %w(number checkbox decimal text paragraph date).freeze
  CHOICES = ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'].freeze
  SECTION_CHOICES = ['Batman Begins', 'The Dark Knight', 'The Dark Knight Rises'].freeze

  def setup
    super
    Sidekiq::Worker.clear_all
    before_all
  end

  @@before_all_run = false

  def before_all
    @account.sections.map(&:destroy)
    @account.ticket_fields_with_nested_fields.custom_fields.where(level: nil).each {|custom_field| custom_field.destroy }
    return if @@before_all_run
    @account = @account.make_current
    @account.ticket_fields.custom_fields.each(&:destroy)
    CentralPublishWorker::TicketFieldWorker.jobs.clear
    @@before_all_run = true
  end

  def test_ticket_field_payload_for_text
    field = create_custom_field("test_custom_publish_text", "text")
    payload = field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field))
  end

  def test_ticket_field_payload_for_checkbox
    field = create_custom_field("test_custom_publish_checkbox", "checkbox")
    payload = field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field))
  end

  def test_ticket_field_payload_for_decimal
    field = create_custom_field("test_custom_publish_decimal", "decimal")
    payload = field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field))
  end

  def test_ticket_field_payload_for_paragraph
    field = create_custom_field("test_custom_publish_paragraph", "paragraph")
    payload = field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field))
  end
  
  def test_ticket_field_payload_for_date
    field = create_custom_field("test_custom_publish_date", "date")
    payload = field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field))
  end
  
  def test_ticket_field_payload_for_number
    field = create_custom_field("test_custom_publish_number", "number")
    payload = field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field))
  end
  
  def test_ticket_field_payload_for_custom_dropdown
    field = create_custom_field_dropdown('test_custom_dropdown', ['Get Smart', 'Pursuit of Happiness', 'Armaggedon'], '12')
    payload = field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field))
  end

  def test_ticket_field_payload_dropdown_with_section_fields
    field = create_custom_field_dropdown_with_sections
    payload = field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field))
  end

  def test_ticket_field_payload_for_section_fields
    t = Time.now.to_i
    sections = [{ title: "section_payload_test_#{t}", value_mapping: ["Question", "Problem"], ticket_fields: ["number"] }]
    create_section_fields(3, sections)
    section_field = @account.ticket_fields.select{ |f| f.section_field? }.first
    payload = section_field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(section_field))
  end

  def test_ticket_field_payload_for_nested_field
    field = create_dependent_custom_field(%w[test_custom_country test_custom_state test_custom_city], 9)
    field.reload
    payload = field.central_publish_payload.to_json
    payload.must_match_json_expression(ticket_field_publish_pattern(field))
  end
end
