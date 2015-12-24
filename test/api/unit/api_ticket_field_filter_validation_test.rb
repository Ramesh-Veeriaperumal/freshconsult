require_relative '../unit_test_helper'

class ApiTicketFieldFilterValidationTest < ActionView::TestCase
  
  def test_valid
    ticket_field_filter = ApiTicketFieldFilterValidation.new({type: "custom_checkbox"})
    assert ticket_field_filter.valid?
  end

  def test_invalid
    ticket_field_filter = ApiTicketFieldFilterValidation.new({type: "custom_checkboxty"})
    refute ticket_field_filter.valid?
    error = ticket_field_filter.errors.full_messages
    assert error.include?('Type not_included')
  end

end
