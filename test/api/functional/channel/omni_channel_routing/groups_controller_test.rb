require_relative '../../../test_helper'

  class Channel::OmniChannelRouting::GroupsControllerTest < ActionController::TestCase  
    include OcrHelper
    include TicketLoadHelper
    include AgentHelper
    include GroupHelper
    include TicketHelper

    def test_index      
      3.times do
        create_group(@account)
      end
      append_header
      get :index, controller_params(version: 'channel/ocr')
      pattern = []
      Account.current.groups.order(:name).all.each do |group|
        pattern << group_pattern_for_index_ocr(Group.find(group.id))
      end
      assert_response 200
      match_json({groups: pattern.ordered!})
    end

    def test_index_deleted_ticket
    create_group_agent
    initial_group_unassigned_load
    ticket = create_ticket({ deleted: 1 }, @group)
    response = get :unassigned_tasks, controller_params(version: 'channel/ocr', id: @group.id)
    response_body = JSON.parse response.body.gsub('=>', ':')
    expected_json = { unassigned_tasks: [] }
    assert_response 200
    match_json(expected_json)
    ticket.destroy
    destroy_agent_group
  end

  def test_index_spam_ticket
    create_group_agent
    initial_group_unassigned_load
    ticket = create_ticket({ spam: 1 }, @group)
    response = get :unassigned_tasks, controller_params(version: 'channel/ocr', id: @group.id)
    response_body = JSON.parse response.body.gsub('=>', ':')
    expected_json = { unassigned_tasks: [] }
    match_json(expected_json)
    assert_response 200
    ticket.destroy
    destroy_agent_group
  end

  def test_index_sla_timer_on
    create_group_agent
    initial_group_unassigned_load
    ticket = create_ticket({}, @group)
    status = ticket.ticket_status.stop_sla_timer
    ticket.ticket_status.stop_sla_timer = 0
    ticket.ticket_status.save
    response = get :unassigned_tasks, controller_params(version: 'channel/ocr', id: @group.id)
    response_body = JSON.parse response.body.gsub('=>', ':')
    ticket.reload
    expected_json = { unassigned_tasks: [{ id: ticket.display_id, updated_at: (ticket.updated_at.to_f * 1000).to_i }] }
    assert_response 200
    match_json(expected_json)
    ticket.ticket_status.stop_sla_timer = status
    ticket.ticket_status.save
    ticket.destroy
    destroy_agent_group
  end

  def test_index_sla_timer_off
    create_group_agent
    initial_group_unassigned_load
    ticket = create_ticket({}, @group)
    status = ticket.ticket_status.stop_sla_timer
    ticket.ticket_status.stop_sla_timer = 1
    ticket.ticket_status.save
    ticket.reload
    response = get :unassigned_tasks, controller_params(version: 'channel/ocr', id: @group.id)
    response_body = JSON.parse response.body.gsub('=>', ':')
    expected_json = { unassigned_tasks: [] }
    match_json(expected_json)
    ticket.ticket_status.stop_sla_timer = status
    ticket.ticket_status.save
    assert_response 200
    ticket.destroy
    destroy_agent_group
  end
end
