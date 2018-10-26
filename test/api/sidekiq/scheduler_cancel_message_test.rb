require_relative '../unit_test_helper'
require 'sidekiq/testing'
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
    responses = ::Scheduler::CancelMessage.new.perform(job_ids: Array(job_id), group_name: group_name)
    responses.each do |response|
      assert_includes SUCCESS, response.to_i, "Expected one of #{SUCCESS}, got #{response}"
    end
  end

  private

    def job_id
      [Account.current.id, 'reminder', @reminder.id].join('_')
    end

    def group_name
      ::SchedulerClientKeys['todo_group_name']
    end
end
