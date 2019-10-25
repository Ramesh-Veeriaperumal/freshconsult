require_relative '../api/test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class PublishToCentralUtilTest < ActionView::TestCase
  include Middleware::Sidekiq::PublishToCentralUtil
  include ::AccountTestHelper
  def setup
    super
    @account = Account.first || create_new_account
    Account.any_instance.stubs(:current).returns(@account)
    Faraday::Connection.any_instance.stubs(:post).returns(Faraday::Response.new({status: 202}))
    Time.any_instance.stubs(:iso8601).returns('2019-10-18T09:03:53Z')
  end

  def teardown
    Account.any_instance.stubs(:current)
    Faraday::Connection.any_instance.unstub(:post)
    Time.any_instance.unstub(:iso8601)
  end

  def job_enqueued_central_payload(job_data, type)
    {
      payload_type: type,
      account_id: Account.current.id.to_s,
      payload: {
        worker_name: job_data['class'],
        queue_name: job_data['original_queue'],
        job_id: job_data['jid'],
        enqueued_at: Time.now.utc.iso8601,
      },
      pod: PodConfig['CURRENT_POD'],
      region: PodConfig['CURRENT_REGION']
    }
  end

  def job_picked_up_central_payload(job_data, type)
    {
      payload_type: type,
      account_id: Account.current.id.to_s,
      payload: {
        worker_name: job_data['class'],
        queue_name: job_data['original_queue'],
        job_id: job_data['jid'],
        enqueued_at: job_data['enqueued_at'],
        picked_up_at: Time.now.utc.iso8601
      },
      pod: PodConfig['CURRENT_POD'],
      region: PodConfig['CURRENT_REGION']
    }
  end

  def test_publish_data_to_central_for_job_enqueued
    msg = {
      original_queue: 'tickets_export_queue',
      class: 'Tickets::Export::TicketsExport',
      jid: '12d2b12mq9j01cq12uyn190'
    }.stringify_keys
    type = PAYLOAD_TYPE[:job_enqueued]
    response = publish_data_to_central(msg, type)
    assert_equal response[:status], 202
    assert_equal response[:data], job_enqueued_central_payload(msg, type)
  end

  def test_publish_data_to_central_for_job_picked_up
    msg = {
      original_queue: 'tickets_export_queue',
      class: 'Tickets::Export::TicketsExport',
      jid: '12d2b12mq9j01cq12uyn190',
      enqueued_at: '2019-10-18T09:02:53Z'
    }.stringify_keys
    type = PAYLOAD_TYPE[:job_picked_up]
    response = publish_data_to_central(msg, type)
    assert_equal response[:status], 202
    assert_equal response[:data], job_picked_up_central_payload(msg, type)
  end
end
