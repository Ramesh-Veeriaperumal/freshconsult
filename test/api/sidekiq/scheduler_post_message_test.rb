require_relative '../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'todos_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'subscription_test_helper.rb')

class SchedulerPostMessageTest < ActionView::TestCase
  include AccountTestHelper
  include CreateTicketHelper
  include TodosTestHelper
  include SubscriptionTestHelper
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
    refute response.blank?
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

  def test_save_information_in_ticket_schedule
    scheduler_client = Scheduler::PostMessage.new
    ticket = create_test_ticket(email: 'sample@freshdesk.com')
    payload = {
      job_id: ticket_job_id(ticket),
      message_type: ApiTicketConstants::TICKET_DELETE_MESSAGE_TYPE,
      group: ::SchedulerClientKeys['ticket_delete_group_name'],
      scheduled_time: Time.zone.now + 10.minutes,
      data: {
        account_id: Account.current.id,
        ticket_id: ticket.id,
        enqueued_at: Time.now.to_i,
        scheduler_type: ApiTicketConstants::TICKET_DELETE_SCHEDULER_TYPE
      },
      sqs: {
        url: SQS_V2_QUEUE_URLS[SQS[:spam_trash_delete_free_acc_queue]]
      }
    }
    resp_stub = ActionDispatch::TestResponse.new
    resp_stub.header = { x_request_id: rand(100) }
    RestClient::Request.any_instance.stubs(:execute).returns(resp_stub)
    response = scheduler_client.perform(payload: payload)
    ticket.reload
    assert_equal ticket.scheduler_trace_id, response.headers[:x_request_id]
  ensure
    RestClient::Request.any_instance.unstub(:execute)
  end

  def test_post_message_downgrade_policy_reminder
    WebMock.allow_net_connect!
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    Account.current.launch(:downgrade_policy)
    current_subscription = @account.subscription
    new_reminder = get_new_subscription_request(@account, current_subscription.subscription_plan_id - 1, current_subscription.renewal_period)
    params = scheduler_payload("#{@account.id}_activate_downgrade_1", 'helpkit_downgrade_policy_reminder', 1.day.from_now.iso8601, 'https://sqs.us-east-1.amazonaws.com/213293927234/fd_scheduler_downgrade_policy_reminder_queue_dev')
    res = ::Scheduler::PostMessage.new.perform(payload: params)
    refute response.blank?
    assert_includes SUCCESS, res.to_i, "Expected one of #{SUCCESS}, got #{res}"
  end

  def test_post_message_downgrade_policy_reminder_with_invalid_params
    WebMock.allow_net_connect!
    assert_raises(SchedulerService::Errors::BadRequestException) do
      Account.stubs(:current).returns(Account.first)
      @account = Account.current
      current_subscription = @account.subscription
      @account.launch(:downgrade_policy)
      new_reminder = get_new_subscription_request(@account, current_subscription.subscription_plan_id - 1, current_subscription.renewal_period)
      params = scheduler_payload("#{@account.id}_activate_downgrade_1", 'helpkit_downgrade_policy_reminder', 1.day.from_now.iso8601, 'https://sqs.us-east-1.amazonaws.com/213293927234/fd_scheduler_downgrade_policy_reminder_queue_dev')
      params.delete(:scheduled_time)
      ::Scheduler::PostMessage.new.perform(payload: params)
    end
  end

  def test_post_message_monthly_annual_notification
    WebMock.allow_net_connect!
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    params = scheduler_payload("#{@account.id}_monthly_to_annual_4", 'monthly_to_annual_notification', 4.months.from_now.iso8601, 'https://sqs.us-east-1.amazonaws.com/213293927234/switch_to_annual_notification_queue_dev')
    res = ::Scheduler::PostMessage.new.perform(payload: params)
    refute response.blank?
    assert_includes SUCCESS, res.to_i, "Expected one of #{SUCCESS}, got #{res}"
  end

  def test_post_message_monthly_annual_notification_with_invalid_params
    WebMock.allow_net_connect!
    assert_raises(SchedulerService::Errors::BadRequestException) do
      Account.stubs(:current).returns(Account.first)
      @account = Account.current
      params = scheduler_payload("#{@account.id}_monthly_to_annual_4", 'monthly_to_annual_notification', 4.months.from_now.iso8601, 'https://sqs.us-east-1.amazonaws.com/213293927234/switch_to_annual_notification_queue_dev')
      params.delete(:scheduled_time)
      Scheduler::PostMessage.new.perform(payload: params)
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

    def ticket_job_id(ticket)
      [Account.current.id, 'ticket', ticket.id].join('_')
    end

    def scheduler_payload(job_id, group_name, scheduled_time, sqs_queue)
      {
        job_id: job_id,
        group: group_name,
        scheduled_time: scheduled_time,
        data: {
          account_id: @account.id,
          enqueued_at: Time.now.to_i
        },
        sqs: {
          url: sqs_queue
        }
      }
    end
end
