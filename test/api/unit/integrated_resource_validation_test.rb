require_relative '../unit_test_helper'

class IntegratedResourceValidationTest < ActionView::TestCase
  def test_valid
    resource_filter = IntegratedResourceFilterValidation.new(installed_application_id: 1, remote_integratable_type: 'Helpdesk::Tickets', local_integratable_id: 1)
    assert resource_filter.valid?
  end
end
