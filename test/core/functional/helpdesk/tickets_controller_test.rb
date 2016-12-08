require_relative '../../test_helper'
Dir["#{Rails.root}/test/core/functional/helpdesk/ticket_test_cases/*.rb"].each { |file| require file }

class Helpdesk::TicketsControllerTest < ActionController::TestCase

#include helpers
  include TicketsTestHelper
  include DynamoTestHelper
  include LinkTicketAssertions
  include NoteTestHelper

#include tests
  include LinkTicketTests
  include LinkTicketNegativeTests


  def setup
    super
    login_admin
  end

end
