require_relative '../../test_helper'
Dir["#{Rails.root}/test/core/functional/helpdesk/bulk_ticket_actions_test_cases/*.rb"].each { |file| require file }

class Helpdesk::BulkTicketActionsControllerTest < ActionController::TestCase

#include helpers
  include CoreTicketsTestHelper
  include SharedOwnershipTestHelper
  include AccountTestHelper
  include ControllerTestHelper
  include SharedOwnershipAssertions

#include tests
  include SharedOwnershipOnBulkTicketTests
  include SharedOwnershipOnBulkTicketNegativeTests

  def setup
    super
    login_admin
  end

end
