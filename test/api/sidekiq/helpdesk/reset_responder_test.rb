require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
['user_helper.rb', 'group_helper.rb', 'ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'archive_ticket_test_helper.rb')

class ResetResponderTest < ActionView::TestCase
  include UsersHelper
  include GroupHelper
  include TicketHelper
  include ControllerTestHelper
  include ArchiveTicketTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @agent = get_admin
    @agent.make_current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_reset_responder_on_tickets
    user = add_new_user(@account)
    agent = add_agent(@account, role_ids: [4], active: 1, email: "testxyz@yopmail.com")
    ticket_ids = []
    rand(1..10).times { ticket_ids << create_ticket(requester_id: user.id, responder_id: agent.id).id }
    Helpdesk::ResetResponder.new.perform(user_id: agent.id, reason: { delete_agent: agent.id })
    @account.tickets.find_all_by_id(ticket_ids).each do |tkt|
      assert tkt.responder.nil?
    end
  end

  def test_trigger_sbrr
    user = add_new_user(@account)
    @account.stubs(:skill_based_round_robin_enabled?).returns(true)
    group = create_group @account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:skill_based]
    agent = add_agent(@account, role_ids: [4], active: 1, email: "testxyz@yopmail.com", group_id: group.id)
    ticket_ids = []
    10.times { ticket_ids << create_ticket({ requester_id: user.id, responder_id: agent.id }, group).id }
    assert_nothing_raised do
      Helpdesk::ResetResponder.new.perform(user_id: agent.id, reason: { delete_agent: agent.id })
    end
  ensure
    @account.unstub(:skill_based_round_robin_enabled?)
  end

  def test_publish_to_ocr_with_feature_turned_off
    user = add_new_user(@account)
    @account.stubs(:omni_channel_routing_enabled?).returns(false)
    group = create_group @account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:load_based_omni_channel_assignment]
    agent = add_agent(@account, role_ids: [4], active: 1, email: "testxyz@yopmail.com", group_id: group.id)
    ticket_ids = []
    10.times { ticket_ids << create_ticket({ requester_id: user.id, responder_id: agent.id }, group).id }
    ::OmniChannelRouting::TaskSync.jobs.clear
    Helpdesk::ResetResponder.new.perform(user_id: agent.id, reason: { delete_agent: agent.id })
    @account.tickets.find_all_by_id(ticket_ids).each do |tkt|
      assert tkt.responder.nil?
    end
    assert_equal 0, ::OmniChannelRouting::TaskSync.jobs.size
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
  end

  def test_publish_tickets_to_ocr_on_responder_reset
    user = add_new_user(@account)
    @account.stubs(:omni_channel_routing_enabled?).returns(true)
    group = create_group @account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:load_based_omni_channel_assignment]
    agent = add_agent(@account, role_ids: [4], active: 1, email: "testxyz@yopmail.com", group_id: group.id)
    ticket_ids = []
    10.times { ticket_ids << create_ticket({ requester_id: user.id, responder_id: agent.id }, group).id }
    ::OmniChannelRouting::TaskSync.jobs.clear
    Helpdesk::ResetResponder.new.perform(user_id: agent.id, reason: { delete_agent: agent.id })
    @account.tickets.find_all_by_id(ticket_ids).each do |tkt|
      assert tkt.responder.nil?
    end
    assert_equal 10, ::OmniChannelRouting::TaskSync.jobs.size
  ensure
    @account.unstub(:omni_channel_routing_enabled?)
  end

  def test_reset_responder_with_shared_ownership_enabled
    user = add_new_user(@account)
    @account.stubs(:shared_ownership_enabled?).returns(true)
    group = create_group @account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:load_based_omni_channel_assignment]
    internal_agent = add_agent(@account, name: Faker::Name.name, email: Faker::Internet.email, active: 1, role: 1, role_ids: [@account.roles.agent.first.id.to_s], agent: 1, group_id: group.id)
    ticket_ids = []
    rand(1..10).times { ticket_ids << create_ticket(internal_agent_id: internal_agent.id).id }
    Helpdesk::ResetResponder.new.perform(user_id: internal_agent.id, reason: { delete_agent: internal_agent.id })
    @account.tickets.find_all_by_id(ticket_ids).each do |tkt|
      assert tkt.internal_agent_id.nil?
    end
  ensure
    @account.unstub(:shared_ownership_enabled?)
  end

  def test_assign_tickets_to_agents_with_capping_enabled
    user = add_new_user(@account)
    Group.any_instance.stubs(:capping_enabled?).returns(true)
    group = create_group @account, ticket_assign_type: Group::TICKET_ASSIGN_TYPE[:load_based_omni_channel_assignment]
    agent = add_agent(@account, role_ids: [4], active: 1, email: 'testxyz@yopmail.com', group_id: group.id)
    ticket_ids = []
    rand(1..10).times { ticket_ids << create_ticket({ requester_id: user.id, responder_id: agent.id }, group).id }
    Helpdesk::ResetResponder.new.perform(user_id: agent.id, reason: { delete_agent: agent.id })
    @account.tickets.find_all_by_id(ticket_ids).each do |tkt|
      assert tkt.responder.nil?
    end
  ensure
    Group.any_instance.unstub(:capping_enabled?)
  end

  def test_pusblish_tickets_with_archive_tickets_included
    enable_archive_tickets do
      user = add_new_user(@account)
      agent = add_agent(@account, role_ids: [4], active: 1, email: 'testxyz@yopmail.com')
      ticket_ids = []
      rand(1..10).times { ticket_ids << create_ticket(requester_id: user.id, responder_id: agent.id).id }
      Helpdesk::ResetResponder.new.perform(user_id: agent.id, reason: { delete_agent: agent.id })
      @account.tickets.find_all_by_id(ticket_ids).each do |tkt|
        assert tkt.responder.nil?
      end
    end
  end

  def test_reset_responder_with_exception
    assert_nothing_raised do
      user = add_new_user(@account)
      agent = add_agent(@account, role_ids: [4], active: 1, email: 'testxyz@yopmail.com')
      ticket_ids = []
      rand(1..10).times { ticket_ids << create_ticket(requester_id: user.id, responder_id: agent.id).id }
      Account.any_instance.stubs(:tickets).raises(RuntimeError)
      Helpdesk::ResetResponder.new.perform(user_id: agent.id, reason: { delete_agent: agent.id })
      Account.any_instance.unstub(:tickets)
    end
  end
end
