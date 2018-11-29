require_relative '../../test_helper'
['ticket_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

class TicketFieldTest < ActiveSupport::TestCase
  include TicketFieldsTestHelper

  def test_duplicate_ticket_status
    locale = I18n.locale
    I18n.locale = 'de'
    last_position_id = @account.ticket_statuses.last.position
    status_custom_field = @account.ticket_fields.find_by_field_type('default_status')
    status_custom_field.update_attributes(sample_status_ticket_fields('de', 'open', 'open', last_position_id))
    assert_equal last_position_id, @account.ticket_statuses.last.position
    ensure
      I18n.locale = locale
  end

  def test_translate_key_value
    locale = I18n.locale
    I18n.locale = 'de'
    last_position_id = @account.ticket_statuses.last.position
    status_custom_field = @account.ticket_fields.find_by_field_type('default_status')
    status_custom_field.update_attributes(sample_status_ticket_fields('de', 'support', 'support',last_position_id))
    assert_equal last_position_id+1, @account.ticket_statuses.last.position
    ensure
      I18n.locale = locale
  end
  
  def test_change_status_customer_name
    locale = I18n.locale
    I18n.locale = 'de'
    prev_status = @account.ticket_statuses.where(status_id: 2).first
    status_custom_field = @account.ticket_fields.find_by_field_type('default_status')
    status_custom_field.update_attributes(sample_status_ticket_fields('de', 'open', 'Edited', prev_status.position))
    curr_status = @account.ticket_statuses.where(status_id: 2).first
    assert_not_equal prev_status.customer_display_name, curr_status.customer_display_name
    ensure
      I18n.locale = locale
  end
end