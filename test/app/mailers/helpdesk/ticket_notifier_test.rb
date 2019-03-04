require_relative '../../../test_helper.rb'
require_relative '../../../api/helpers/test_class_methods.rb'
require_relative '../../../core/helpers/account_test_helper.rb'
require_relative '../../../core/helpers/controller_test_helper.rb'
require_relative '../../../core/helpers/users_test_helper.rb'
require_relative '../../../core/helpers/tickets_test_helper.rb'
['ticket_helper.rb', 'user_helper.rb'].each { |file| require Rails.root.join("spec/support/#{file}") }

class TicketNotifierTest < ActionMailer::TestCase
  include AccountTestHelper
  include ControllerTestHelper
  include CoreUsersTestHelper
  include CoreTicketsTestHelper
  include TicketHelper
  include UsersHelper
  
  def setup
    get_agent
    @ticket = create_ticket
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
    super
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

  def test_agent_assign_email_notification_go_for_ticket
    agent = add_test_agent(@account)
    ticket = create_ticket({ email: 'sample@freshdesk.com', source: Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email], responder_id: agent.id })
    enable_agent_assign_notification
    Mail::Message.any_instance.expects(:deliver).once
    Helpdesk::TicketNotifier.notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_AGENT, ticket)
  end

  def test_agent_assign_email_notification_dont_go_for_service_ticket_ticket
    agent = add_test_agent(@account)
    ticket = create_service_task_ticket({ email: 'sample@freshdesk.com', source: Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email], responder_id: agent.id })
    enable_agent_assign_notification
    Mail::Message.any_instance.expects(:deliver).never
    Helpdesk::TicketNotifier.notify_by_email(EmailNotification::TICKET_ASSIGNED_TO_AGENT, ticket)
  end

  def enable_agent_assign_notification
    e_notification = @account.email_notifications.find_by_notification_type(EmailNotification::TICKET_ASSIGNED_TO_AGENT)
    e_notification.update_attributes({ agent_notification: true })
  end

end