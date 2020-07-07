['group_helper.rb', 'agent_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module GroupsTestHelper
  include GroupHelper
  include AgentHelper
  # Patterns

  RR_OCR_GROUPS = [
    {
      'id': 100,
      'product': 'freshdesk',
      'product_group_id': '100',
      'name': 'Freshdesk Group 1',
      'round_robin': 1
    },
    {
      'id': 101,
      'product': 'freshchat',
      'product_group_id': 'abcd',
      'name': 'Freshchat Group 1',
      'round_robin': 1
    },
    {
      'id': 102,
      'product': 'freshchat',
      'product_group_id': 'efgh',
      'name': 'Freshchat Group 2',
      'round_robin': 10
    },
    {
      'id': 104,
      'product': 'freshcaller',
      'product_group_id': '1001',
      'name': 'Freshcaller Group 1',
      'round_robin': 1
    }
  ].freeze
  NO_RR_OCR_GROUPS = [
    {
      'id': 103,
      'product': 'freshchat',
      'product_group_id': 'ijkl',
      'name': 'Freshchat Group 3'
    },
    {
      'id': 105,
      'product': 'freshcaller',
      'product_group_id': '1002',
      'name': 'Freshcaller Group 2'
    }
  ].freeze

  def private_group_pattern(expected_output={}, group)    
    group_json = group_json(expected_output, group)
    group_json.delete(:business_hour_id)    
    group_json[:business_hour]=business_hour_hash(expected_output, group) if is_business_hour_present?(expected_output,group)    
    group_json[:assignment_type]=GroupConstants::DB_ASSIGNMENT_TYPE_FOR_MAP[group.ticket_assign_type] 
    group_json[:agent_ids] = group.agent_groups.pluck(:user_id)    
    group_json
  end 

  def private_group_pattern_index(expected_output = {}, group)
    group_json = group_json(expected_output, group)
    group_json.delete(:business_hour_id)
    group_json.delete(:unassigned_for)
    group_json.delete(:created_at)
    group_json.delete(:updated_at)
    group_json.delete(:group_type)
    group_json.delete(:escalate_to)
    group_json[:agent_ids] = group.agent_groups.pluck(:user_id)
    group_json
  end

  def private_group_pattern_with_lbrr_by_omniroute(expected_output={}, group)
    group_json=private_group_pattern(expected_output={},group)
    group_json[:allow_agents_to_change_availability]= group.toggle_availability if lbrr_by_omniroute_enabled?
    group_json[:round_robin_type]=get_round_robin_type(group) if lbrr_by_omniroute_enabled?
    group_json
  end

  def private_group_pattern_with_ocr(expected_output={}, group)
    group_json=private_group_pattern(expected_output={},group)
    group_json[:allow_agents_to_change_availability]= group.toggle_availability if ocr_enabled?
    group_json
  end 

  def private_group_pattern_with_normal_round_robin(expected_output={}, group)
    group_json=private_group_pattern(expected_output={},group)    
    group_json[:allow_agents_to_change_availability]= group.toggle_availability if round_robin_enabled?
    group_json[:round_robin_type]=get_round_robin_type(group) if round_robin_enabled?    
    group_json
  end
  
  def private_group_pattern_with_lbrr(expected_output={}, group)
    group_json=private_group_pattern(expected_output={},group)    
    group_json[:allow_agents_to_change_availability]= group.toggle_availability if round_robin_enabled?
    group_json[:round_robin_type]=get_round_robin_type(group) if round_robin_enabled? 
    group_json[:capping_limit]=group.capping_limit if round_robin_enabled?
    group_json
  end  
  
  def private_group_pattern_with_sbrr(expected_output={}, group)
    group_json=private_group_pattern(expected_output={},group)    
    group_json[:allow_agents_to_change_availability]= group.toggle_availability if round_robin_enabled?
    group_json[:round_robin_type]=get_round_robin_type(group) if round_robin_enabled?  && sbrr_enabled?
    group_json[:capping_limit]=group.capping_limit if round_robin_enabled? && sbrr_enabled?  
    group_json
  end  

  def group_pattern(expected_output = {}, group)
    group_json = group_json(expected_output, group)
    group_json[:auto_ticket_assign] = decorate_boolean((expected_output[:auto_ticket_assign] || group.ticket_assign_type)) if round_robin_enabled?
    group_json[:agent_ids] = group.agent_groups.pluck(:user_id)
    group_json
  end

  def group_pattern_without_assingn_type(expected_output = {}, group)
    group_json = group_json(expected_output, group)
    group_json[:agent_ids] = group.agent_groups.pluck(:user_id)
    group_json
  end

  def group_pattern_for_index(expected_output = {}, group)
    group_json = group_json(expected_output, group)
    group_json[:auto_ticket_assign] = (expected_output[:auto_ticket_assign] || group.ticket_assign_type).to_s.to_bool
    group_json
  end  

  def group_json(expected_output, group)
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum,
      name: expected_output[:name] || group.name,
      description: expected_output[:description] || group.description,     
      business_hour_id: expected_output[:business_hour_id] || group.business_calendar_id,
      group_type: expected_output[:group_type] || GroupType.group_type_name(group.group_type),
      escalate_to: expected_output[:escalate_to] || group.escalate_to,
      unassigned_for: expected_output[:unassigned_for] || (GroupConstants::UNASSIGNED_FOR_MAP.key(group.assign_time)),
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def business_hour_hash(expected_output, group)
    business_hour_id=expected_output[business_hour_id].nil? ? group.business_calendar_id : expected_output[business_hour_id]
    business_hour=Account.current.business_calendar.find_by_id(business_hour_id)
    return business_hour if business_hour.nil?
    result=Hash.new
    result[:id]=business_hour.id
    result[:name]=business_hour.name    
    result
  end

  def is_business_hour_present?(expected_output, group)
    business_hour_id=expected_output[business_hour_id].nil? ? group.business_calendar_id : expected_output[business_hour_id]
    business_hour=Account.current.business_calendar.find_by_id(business_hour_id)
    return business_hour.nil? ? false : true
  end

  def decorate_boolean(value)
    value ? value.to_s.to_bool : value
  rescue ArgumentError => ex
    value
  end

  def omni_channel_groups_response(auto_assignment = true)
    channel_groups = RR_OCR_GROUPS
    channel_groups += NO_RR_OCR_GROUPS unless auto_assignment
    { 'ocr_groups': channel_groups }
  end

  def omni_channel_groups_pattern(channel_group, auto_assignment = true)
    channel = channel_group['product']
    return if channel == 'freshdesk'

    channel_tat = OmniChannelRouting::Constants::OCR_TAT_MAPPING[channel.to_sym].key(channel_group['round_robin'])
    channel_tat = channel_tat ? "#{channel}_#{channel_tat}" : 'default'
    return if auto_assignment && channel_tat == 'default'

    hash = {
      id: channel_group['product_group_id'],
      name: channel_group['name'],
      channel: channel
    }
    hash[:round_robin_type] = GroupConstants::CHANNEL_TASK_ASSIGNMENT_TYPES[channel_tat.to_sym]
    hash
  end

  # Helpers
  def group_payload
    { group: v1_group_params }.to_json
  end

  def v2_group_payload
    v2_group_params.to_json
  end

  # private

  def agents_ids_array
    agent1 = Agent.first || add_test_agent(@account, role: Role.find_by_name('Agent').id).agent
    agent2 = Agent.where('id != ?', agent1.user_id).first || add_test_agent(@account, role: Role.find_by_name('Agent').id).agent
    [agent1.user_id, agent2.user_id]
  end

  def agent_ids_csv
    agents_ids_array.join(',')
  end

  def v1_group_params
    { name: Faker::Name.name,  description: Faker::Lorem.paragraph, agent_list: agent_ids_csv }
  end

  def v2_group_params
    { name: Faker::Name.name,  description: Faker::Lorem.paragraph, agent_ids: agents_ids_array }
  end

  def round_robin_enabled?
    Account.current.features?(:round_robin)
  end

  def sbrr_enabled?
    Account.current.skill_based_round_robin_enabled?
  end

  def ocr_enabled?
    Account.current.omni_channel_routing_enabled?
  end 

  def lbrr_by_omniroute_enabled?
    Account.current.lbrr_by_omniroute_enabled?
  end 

  def get_round_robin_type(group)
    round_robin_type=1 if group.ticket_assign_type==1 && group.capping_limit==0
    round_robin_type=2 if group.ticket_assign_type==1 && group.capping_limit!=0
    round_robin_type=3 if group.ticket_assign_type==2
    round_robin_type=12 if group.ticket_assign_type==12 && group.capping_limit==0
    round_robin_type
  end 
end
