# frozen_string_literal: true

require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class CommandWorkerTest < ActionView::TestCase
  include ::AccountTestHelper

  def setup
    super
    @account = Account.first || create_new_account
    Account.any_instance.stubs(:current).returns(@account)
    @account.make_current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def construct_command_worker_input_payload
    {
      override_payload_type: 'helpkit_reply',
      account_id: @account.id,
      payload: {
        'data' => { 'id' => 2330 },
        'status_code' => 200,
        'command_name' => 'create_ticket'
      }
    }
  end

  def test_command_worker_success_test
    Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new(status: 200))
    args = construct_command_worker_input_payload
    Channel::CommandWorker.new.perform(args)
    assert_equal 0, Channel::CommandWorker.jobs.size
  ensure
    Channel::CommandWorker.jobs.clear
    Faraday::Connection.any_instance.unstub(:post)
  end

  def test_command_worker_failure_test
    Faraday::Connection.any_instance.stubs(:post).raises('Dummy error')
    args = construct_command_worker_input_payload
    Channel::CommandWorker.new.perform(args)
  rescue StandardError => e
    assert_equal e.message, 'Dummy error'
  ensure
    Channel::CommandWorker.jobs.clear
    Faraday::Connection.any_instance.unstub(:post)
  end
end
