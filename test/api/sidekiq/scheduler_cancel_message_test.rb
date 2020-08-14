require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'webmock/minitest'
WebMock.allow_net_connect!
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'todos_test_helper.rb')

class SchedulerCancelMessageTest < ActionView::TestCase
  include AccountTestHelper
  include CreateTicketHelper
  include TodosTestHelper
  SUCCESS = 200..299
  def teardown
    Account.unstub(:current)
    super
  end

  def test_cancel_message_todos_reminder
    Account.stubs(:current).returns(Account.first)
    @user = create_test_account
    @account = Account.current
    Account.current.launch(:todos_reminder_scheduler)
    @ticket = create_test_ticket(email: 'sample@freshdesk.com')
    @reminder = get_new_reminder('test delete', @ticket.id, nil, nil, @user.id)
    stub_request(:delete, %r{^http://scheduler-staging.freshworksapi.com/schedules.*?$}).to_return(status: 202)
    responses = ::Scheduler::CancelMessage.new.perform('job_ids' => Array(job_id), 'group_name' => group_name)
    refute responses.blank?
    responses.each do |response|
      assert_includes SUCCESS, response.to_i, "Expected one of #{SUCCESS}, got #{response}"
    end
  end

  def test_cancel_message_todos_reminder_with_symbolized_args
    Account.stubs(:current).returns(Account.first)
    @user = create_test_account
    @account = Account.current
    Account.current.launch(:todos_reminder_scheduler)
    @ticket = create_test_ticket(email: 'sample@freshdesk.com')
    @reminder = get_new_reminder('test delete', @ticket.id, nil, nil, @user.id)
    stub_request(:delete, %r{^http://scheduler-staging.freshworksapi.com/schedules.*?$}).to_return(status: 202)
    responses = ::Scheduler::CancelMessage.new.perform(job_ids: Array(job_id), group_name: group_name)
    responses.each do |response|
      assert_includes SUCCESS, response.to_i, "Expected one of #{SUCCESS}, got #{response}"
    end
  end

  def test_save_information_in_ticket_schedule
    scheduler_client = Scheduler::CancelMessage.new
    ticket = create_test_ticket(email: 'sample@freshdesk.com')
    resp_stub = ActionDispatch::TestResponse.new
    resp_stub.header = { x_request_id: rand(100) }
    RestClient::Request.any_instance.stubs(:execute).returns(resp_stub)
    responses = scheduler_client.perform(job_ids: Array(ticket_job_id(ticket)), group_name: ::SchedulerClientKeys['ticket_delete_group_name']) 
    ticket.reload
    assert_equal ticket.scheduler_trace_id, responses.first.headers[:x_request_id]
  ensure
    RestClient::Request.any_instance.unstub(:execute)
  end

  def test_cancel_message_monthly_annual_notification
    WebMock.allow_net_connect!
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    responses = ::Scheduler::CancelMessage.new.perform(job_ids: Array("#{@account.id}_monthly_to_annual_4"), group_name: ::SchedulerClientKeys['monthly_to_annual_group_name'])
    responses.each do |response|
      assert_includes SUCCESS, response.to_i, "Expected one of #{SUCCESS}, got #{response}"
    end
  ensure
    WebMock.disable_net_connect!
  end

  private

    def job_id
      [Account.current.id, 'reminder', @reminder.id].join('_')
    end

    def ticket_job_id(ticket)
      [Account.current.id, 'ticket', ticket.id].join('_')
    end

    def group_name
      ::SchedulerClientKeys['todo_group_name']
    end
end
