require_relative '../../test_helper'
Dir["#{Rails.root}/test/core/functional/helpdesk/ticket_test_cases/*.rb"].each { |file| require file }

class Helpdesk::TicketsControllerTest < ActionController::TestCase

  # include helpers
  include CoreTicketsTestHelper
  include DynamoTestHelper
  include LinkTicketAssertions
  include NoteTestHelper
  include SharedOwnershipTestHelper
  include AccountTestHelper
  include CoreUsersTestHelper
  include ControllerTestHelper

  # include tests
  include LinkTicketTests
  include LinkTicketNegativeTests
  include TicketDetailsTests
  include TicketDetailsNegativeTests
  include TicketListTests
  include TicketListNegativeTests

  def setup
    super
    login_admin
  end

end
