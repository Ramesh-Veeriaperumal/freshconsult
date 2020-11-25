# frozen_string_literal: true

require_relative '../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class ScheduledTaskBaseTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    account = create_test_account(Faker::Internet.domain_word.to_s, Faker::Internet.email)
    Account.stubs(:current).returns(account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def delete_account(account_id)
    Subscription.any_instance.stubs(:state).returns('suspended')
    args = {}
    args['account_id'] = account_id
    args['continue_account_destroy_from'] = 1
    Sidekiq::Testing.inline! do
      AccountCleanup::DeleteAccount.new.perform(args)
    end
  end

  def test_scheduled_report_with_invalid_account
    account_id = Account.current.id
    delete_account(account_id)
    account_after_delete = Account.find_by_id(account_id)
    assert_nil account_after_delete
    params = { task_id: Faker::Number.number(10), next_run_at: Faker::Number.number(10), account_id: account_id }
    Sidekiq::Testing.inline! do
      ScheduledTaskBase.new.perform(params)
    end
    assert_not_send([NewRelic::Agent, :notice_error, ShardNotFound, { description: "Error on executing scheduled task #{params}" }])
  end
end
