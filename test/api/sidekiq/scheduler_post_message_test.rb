require_relative '../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'todos_test_helper.rb')

class SchedulerPostMessageTest < ActionView::TestCase
  include AccountTestHelper
  include CreateTicketHelper
  include TodosTestHelper
  SUCCESS = 200..299
  def teardown
    Account.unstub(:current)
    WebMock.disable_net_connect!
    super
  end

  def test_post_message_todos_reminder
    # TODO: Stub all external requests instead of the below hack
    WebMock.allow_net_connect!
    Account.stubs(:current).returns(Account.first)
    @user = create_test_account
    @account = Account.current
    Account.current.launch(:todos_reminder_scheduler)
    @ticket = create_test_ticket(email: 'sample@freshdesk.com')
    @reminder = get_new_reminder('test delete', @ticket.id, nil, nil, @user.id)
    params = todo_job_params
    res = ::Scheduler::PostMessage.new.perform(payload: params)
    assert_includes SUCCESS, res.to_i, "Expected one of #{SUCCESS}, got #{res}"
  end

  def test_post_message_todos_reminder_with_invalid_params
    WebMock.allow_net_connect!
    assert_raises(SchedulerService::Errors::BadRequestException) do
      Account.stubs(:current).returns(Account.first)
      @user = create_test_account
      @account = Account.current
      Account.current.launch(:todos_reminder_scheduler)
      @ticket = create_test_ticket(email: 'sample@freshdesk.com')
      @reminder = get_new_reminder('test delete', @ticket.id, nil, nil, @user.id)
      params = todo_job_params
      params.delete(:scheduled_time)
      ::Scheduler::PostMessage.new.perform(payload: params)
    end
  end

  private

    def todo_job_params
      {
        job_id: "#{@account.id}_reminder_#{@reminder.id}",
        message_type: 'todos_schedule',
        group: 'helpkit_todo_reminder',
        data: {
          account_id: @account.id,
          reminder_id: @reminder.id,
          enqueued_at: Time.now.to_i,
          scheduler_type: 'todos_reminder'
        },
        sqs: {
          url: 'http://sqs.us-east-1.amazonaws.com/213293927234/fd_scheduler_reminder_todo_queue_test'
        },
        scheduled_time: 1.day.from_now.iso8601
      }
    end
end
