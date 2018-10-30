require_relative '../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'todos_test_helper.rb')
class SchedulerPollerTodosReminderTest < ActionView::TestCase
  include AccountTestHelper
  include CreateTicketHelper
  include TodosTestHelper
  def teardown
    Account.unstub(:current)
    super
  end

  def test_scheduler_poll_message_todos_reminder
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @user = create_test_account
    Account.current.launch(:todos_reminder_scheduler)
    @ticket = create_test_ticket(email: 'sample@freshdesk.com')
    @reminder = get_new_reminder('test delete', @ticket.id, nil, nil, @user.id, 1.day.from_now.iso8601)
    args = { 'account_id' => @account.id, 'reminder_id' => @reminder.id,
             'enqueued_at' => 1516266671, 'scheduler_type' => 'todos_reminder' }
    response = Ryuken::SchedulerPollerTodosReminder.new.perform(nil, args)
    assert_equal response, true
  end
end
