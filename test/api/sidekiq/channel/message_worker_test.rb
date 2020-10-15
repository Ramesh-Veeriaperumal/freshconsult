require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

class MessageWorkerTest < ActionView::TestCase
  include ::AccountTestHelper
  include ::CoreUsersTestHelper

  def setup
    super
    @account = Account.first || create_new_account
    @account.make_current
    @agent ||= add_test_agent
    @agent.make_current
  end

  def test_message_worker_to_post_message_successfully
    Faraday::Request::Retry.any_instance.stubs(:call).returns(Faraday::Response.new(status: 200))
    Channel::MessageWorker.jobs.clear
    Sidekiq::Testing.inline! do
      args = { body: Faker::Lorem.paragraph, channel_id: 12, profile_unique_id: '+2389238', ticket_id: 23 }
      Channel::MessageWorker.perform_async(args)
    end
    assert_equal 0, Channel::MessageWorker.jobs.size
  ensure
    Faraday::Request::Retry.any_instance.unstub(:call)
  end

  def test_message_worker_to_throw_error
    Faraday::Connection.any_instance.stubs(:post).raises('Connection error')
    args = { body: Faker::Lorem.paragraph, channel_id: 12, profile_unique_id: '+2389238' }
    Channel::MessageWorker.new.perform(args)
  rescue StandardError => e
    assert_equal e.message, 'Connection error'
  ensure
    Faraday::Connection.any_instance.unstub(:post)
  end
end
