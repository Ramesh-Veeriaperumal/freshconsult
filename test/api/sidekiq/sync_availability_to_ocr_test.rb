require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'

Sidekiq::Testing.fake!

['agent_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class SyncAgentAvailabilityToOcrTest < ActionView::TestCase
  include AgentHelper
  
  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @agent = add_agent_to_account(@account, options = { role: 4, active: 1, email: "testemail@yopmail.com", available: true })
  end

  def teardown
    @agent.destroy
    Account.unstub(:current)
    super
  end

  #Testcases for worker
  def test_send_availability_ocr_worker_success_response
    assert_nothing_raised do
      Helpdesk::SyncAgentAvailabilityToOcr.any_instance.stubs(:ocr_sync_agent_availability_request).returns(true)
      Helpdesk::SyncAgentAvailabilityToOcr.new.perform({user_id: @agent.user_id, availability: @agent.available})
    end
    ensure
      Helpdesk::SyncAgentAvailabilityToOcr.any_instance.unstub(:ocr_sync_agent_availability_request)
  end

  def test_send_availability_ocr_worker_fail_response
    assert_raises(RuntimeError) do
      Helpdesk::SyncAgentAvailabilityToOcr.any_instance.stubs(:ocr_sync_agent_availability_request).raises(RuntimeError)
      Helpdesk::SyncAgentAvailabilityToOcr.new.perform({user_id: @agent.user_id, availability: @agent.available})
    end
    ensure
      Helpdesk::SyncAgentAvailabilityToOcr.any_instance.unstub(:ocr_sync_agent_availability_request)
  end

end