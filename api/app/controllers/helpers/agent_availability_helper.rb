module AgentAvailabilityHelper
  class LiveChatAPIError < StandardError
  end
  include ChatHelper # Need to include for only agent availability calls.

  def agents_availability_count
    result = {}
    result[:ticket_assignment] = available_rr_agents_count
    # chat_count = available_chat_agents -> commenting out for now. Will test once Chat is setup.
    # result[:chat] = chat_count if chat_count
    result
  end

  def available_chat_agents
    if Account.current.freshchat_enabled?
      path = 'agents/available'
      proxy_response = livechat_request 'available', {}, path, 'GET'
      proxy_response = JSON.parse proxy_response[:text]
      proxy_response['data']['count'] if proxy_response['status'] == 'success' && proxy_response['data']
    end
  end

  def external_agents_availability
    livechat_map = nil # livechat_agent_details -> commenting out for now. Will test once Chat is setup.
    parse_external_agents_response round_robin_groups, livechat_map
  end

  def round_robin_groups
    current_user.privilege?(:admin_tasks) ? current_account.groups_from_cache.select { |group| group.ticket_assign_type > 0 }.map(&:id) : current_user.accessible_roundrobin_groups.map(&:id)
  end

  def livechat_agent_details
    return nil unless current_account.freshchat_enabled?
    livechat_response = livechat_request('get_agents_availability', {}, 'agents/getLastActivityAt', 'GET')[:text]
    livechat_agents = JSON.parse livechat_response
    raise LiveChatAPIError if livechat_agents['status'] != 'success'
    livechat_agents['data'].map { |d| [d['agent_id'], d] }.to_h
  rescue => e
    Rails.logger.error "get_livechat_agent_details #{e}, Message: #{livechat_agents.inspect}"
    nil
  end

  def parse_external_agents_response(rr_groups, livechat_map = nil)
    return if rr_groups.empty? && livechat_map.nil?
    @availability_details = {}
    @availability_details = Hash[build_external_agents_hash(rr_groups, livechat_map)]
  end

  def build_external_agents_hash(rr_groups, livechat_map)
    scoper.map do |agent|
      user = agent.user
      agent_details = {}
      rr_agent = rr_agent?(rr_groups, agent.group_ids) if rr_groups.present?
      agent_details.merge!(ticket_assignment_details(rr_agent, agent)) if rr_agent
      agent_details.merge!(livechat_details(livechat_map[user.id])) if livechat_map.present? && livechat_map[user.id].present?
      [user.id, agent_details]
    end
  end

  def ticket_assignment_details(rr_agent, agent)
    available = rr_agent && agent.available
    { ticket_assignment: { available: available, round_robin_agent: rr_agent } }
  end

  def livechat_details(live_agent)
    { live_chat: { available: live_agent['available'], last_activity_at: live_agent['last_activity_at'], ongoing_chat_count: live_agent['onGoingChatCount'] } }
  end

  def rr_agent?(rr_groups, group_ids)
    ((rr_groups || []) & (group_ids || [])).present?
  end
end
