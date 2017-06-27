require_relative '../unit_test_helper'
class IntegratedResourceFilterValidationTest < ActionView::TestCase
  def test_valid
    resource_filter = IntegratedResourceFilterValidation.new(installed_application_id: 1, remote_integratable_type: 'Helpdesk::Tickets', local_integratable_id: 1)
    assert resource_filter.valid?
  end

  def test_invalid
    resource_filter = IntegratedResourceFilterValidation.new(remote_integratable_type: 'Helpdesk::Tickets', local_integratable_id: 1)
    refute resource_filter.valid?
    error = resource_filter.errors.full_messages
    assert error.include?('Installed application installed_application_id_required')
  end
end
