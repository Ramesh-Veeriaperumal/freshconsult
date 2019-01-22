require_relative '../../../test_helper.rb'
require_relative '../../../api/helpers/test_class_methods.rb'
require_relative '../../../core/helpers/account_test_helper.rb'
require_relative '../../../core/helpers/controller_test_helper.rb'
require_relative '../../../core/helpers/users_test_helper.rb'
require_relative '../../../core/helpers/tickets_test_helper.rb'

class TicketNotifierTest < ActionMailer::TestCase
  include AccountTestHelper
  include ControllerTestHelper
  include UsersTestHelper
  include TicketsTestHelper

  def setup
    get_agent
    @ticket = create_ticket
  end

  def test_email_gets_sent_without_no_agent_when_responder_is_nil
    Account.any_instance.stubs(:features?).returns(true)
    email = Helpdesk::TicketNotifier.deliver_notify_outbound_email(@ticket)
    Account.any_instance.unstub(:features?)
    assert_equal true, email[:from].value[0].include?("Test Account")
  end

  def test_email_gets_sent_with_agent_name_when_responder_is_not_nil
    user = User.first
    @ticket.responder = user
    Account.any_instance.stubs(:features?).returns(true)
    email = Helpdesk::TicketNotifier.deliver_notify_outbound_email(@ticket)
    Account.any_instance.unstub(:features?)
    assert_equal true, email[:from].value[0].include?(user.name)
  end

end