require_relative '../../../test_helper'
class Channel::OmniChannelRouting::AgentsControllerTest < ActionController::TestCase  
  include OcrHelper
  include TicketLoadHelper
  include AgentHelper
  include GroupHelper
  include TicketHelper

  def test_index
    3.times do
      create_group(Account.current)
    end
    append_header
    get :index, controller_params(version: 'channel/ocr')
    pattern = []
    Account.current.agents.order(:name).all.each do |agent|
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
end
