require_relative '../../test_helper'
Dir["#{Rails.root}/test/core/functional/helpdesk/automation_test_cases/*.rb"].each { |file| require file }

class Admin::VaRulesControllerTest < ActionController::TestCase

#include helpers
  include CoreTicketsTestHelper
  #include DynamoTestHelper
 # include LinkTicketAssertions
  include NoteTestHelper
  include CoreUsersTestHelper
  include AccountTestHelper

#include tests
  #include LinkTicketTests
  #include LinkTicketNegativeTests
  include DispatcherTests
  include DispatcherNegativeTests

  def setup
    super
    login_admin
  end

end
