require_relative '../../../test_helper'
class Channel::OmniChannelRouting::AgentsControllerTest < ActionController::TestCase  
  include OcrHelper
  include TicketLoadHelper
  include AgentHelper
  include GroupHelper
  include TicketHelper
  include AgentsTestHelper

  def wrap_cname(params)
    { agent: params }
  end

  def test_index
    3.times do
      create_group(Account.current)
    end
    append_header
    get :index, controller_params(version: 'channel/ocr')
    pattern = []
    Account.current.agents.each do |agent|
      pattern << agent_pattern_for_index_ocr(agent)
    end
    assert_response 200
    match_json({agents: pattern.ordered!})
  end

  def test_index_deleted_ticket
    create_group_agent
    initial_agent_load
    ticket = create_ticket(responder_id: @agent.user_id, deleted: 1)
    response = get :task_load, controller_params(version: 'channel/ocr', id: @agent.user_id)
    response_body = JSON.parse response.body.gsub('=>', ':')
    assert_equal @count, response_body['task_load']
    assert_response 200
    ticket.destroy
    destroy_agent_group
  end

  def test_index_spam_ticket
    create_group_agent
    initial_agent_load
    ticket = create_ticket(responder_id: @agent.user_id, spam: 1)
    response = get :task_load, controller_params(version: 'channel/ocr', id: @agent.user_id)
    response_body = JSON.parse response.body.gsub('=>', ':')
    assert_equal @count, response_body['task_load']
    assert_response 200
    ticket.destroy
    destroy_agent_group
  end

  def test_index_sla_timer_on
    create_group_agent
    initial_agent_load
    ticket = create_ticket(responder_id: @agent.user_id)
    status = ticket.ticket_status.stop_sla_timer
    ticket.ticket_status.stop_sla_timer = 0
    ticket.ticket_status.save
    response = get :task_load, controller_params(version: 'channel/ocr', id: @agent.user_id)
    response_body = JSON.parse response.body.gsub('=>', ':')
    assert_equal @count, response_body['task_load'] - 1
    assert_response 200
    ticket.ticket_status.stop_sla_timer = status
    ticket.ticket_status.save
    ticket.destroy
    destroy_agent_group
  end

  def test_index_sla_timer_off
    create_group_agent
    initial_agent_load
    ticket = create_ticket(responder_id: @agent.user_id)
    status = ticket.ticket_status.stop_sla_timer
    ticket.ticket_status.stop_sla_timer = 1
    ticket.ticket_status.save
    ticket.reload
    response = get :task_load, controller_params(version: 'channel/ocr', id: @agent.user_id)
    response_body = JSON.parse response.body.gsub('=>', ':')
    assert_equal @count, response_body['task_load']
    ticket.ticket_status.stop_sla_timer = status
    ticket.ticket_status.save
    assert_response 200
    ticket.destroy
    destroy_agent_group
  end

  def test_update_agent_availability
    @account.add_feature(:omni_channel_routing)
    @agent = add_agent_to_account(@account, active: 1, role: 4, available: false, email: Faker::Internet.email)
    OmniChannelRouting::AgentSync.jobs.clear
    append_header(@agent.user_id)
    @account.agent_groups.create(user_id: @agent.user_id, group_id: @account.groups.first.id)
    @account.groups.first.update_column(:toggle_availability, true) # rubocop:disable Rails/SkipsModelValidations
    params = { availability: true }
    put :update, construct_params({ version: 'channel/ocr', id: @agent.user_id }, params)
    assert_response 200
    assert_equal @agent.user_id, User.current.id
    @agent.reload
    match_json(agent_pattern_with_additional_details({available: params[:availability]}, @agent.user))
    match_json(agent_pattern_with_additional_details({}, @agent.user))
    assert_equal 0, OmniChannelRouting::AgentSync.jobs.size
  ensure
    @account.revoke_feature(:omni_channel_routing)
    User.reset_current_user
  end
end
