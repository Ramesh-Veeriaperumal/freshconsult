require_relative '../../test_helper'
['ticket_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

class TicketFieldTest < ActiveSupport::TestCase
  include TicketFieldsTestHelper

  def test_duplicate_ticket_status
    locale = I18n.locale
    I18n.locale = 'de'
    last_position_id = @account.ticket_statuses.last.position
    status_custom_field = @account.ticket_fields.find_by_field_type('default_status')
    status_custom_field.update_attributes(sample_status_ticket_fields 'de')
    assert_equal last_position_id, @account.ticket_statuses.last.position
    ensure
      I18n.locale = locale
  end
end