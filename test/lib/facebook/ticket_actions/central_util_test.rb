require_relative '../../../api/unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

class CentralUtilTest < ActionView::TestCase
  include Facebook::TicketActions::CentralUtil

  def setup
    Account.stubs(:current).returns(Account.first || create_test_account)
    Channel::CommandWorker.jobs.clear
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def construct_error_args
    {
      error_code: 531,
      error_msg: 'custom_error',
      note_id: 1,
      note_created_at: Time.now.utc,
      msg_type: 'comment',
      fb_page_id: 123,
      fb_post_id: nil
    }
  end

  def construct_success_args
    {
      error_code: nil,
      error_msg: nil,
      note_id: 1,
      note_created_at: Time.now.utc,
      msg_type: 'comment',
      fb_page_id: 123,
      fb_post_id: 1234
    }
  end

  def test_post_success_command
    old_count = Channel::CommandWorker.jobs.size
    args = construct_success_args
    post_success_or_failure_command(args)
    new_count = Channel::CommandWorker.jobs.size
    assert_equal old_count + 1, new_count
    assert_equal true,
                 match_response_payload(Channel::CommandWorker.jobs.last['args'][0]['payload'],
                                        construct_success_args)
  end

  def test_post_failure_command
    old_count = Channel::CommandWorker.jobs.size
    args = construct_error_args
    post_success_or_failure_command(args)
    new_count = Channel::CommandWorker.jobs.size
    assert_equal old_count + 1, new_count
    assert_equal true,
                 match_response_payload(Channel::CommandWorker.jobs.last['args'][0]['payload'],
                                        construct_error_args)
  end

  def match_response_payload(sidekiq_job, args)
    args.delete(:note_created_at)
    args == {
      error_code: sidekiq_job['data'].key?('error') ? sidekiq_job['data']['error']['error_code'] : nil,
      error_msg: sidekiq_job['data'].key?('error') ? sidekiq_job['data']['error']['error_message'] : nil,
      note_id: sidekiq_job['context']['note']['id'],
      msg_type: sidekiq_job['context']['facebook_data']['event_type'],
      fb_page_id: sidekiq_job['context']['facebook_data']['facebook_page_id'],
      fb_post_id: sidekiq_job['data'].key?('error') ? nil : sidekiq_job['data']['details']['facebook_item_id']
    }
  end
end
