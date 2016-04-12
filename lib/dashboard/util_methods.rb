module Dashboard::UtilMethods

  ################################################################################################################
  # Method:: groups_list_from_cache and agent_list_from_cache                                                    #
  # Agent with all tickets scope -  all the groups/agents will be shown if there is no filter_condition          #
  # Agent with group access/restricted access,                                                                   #
  #     - if Group_By is group, we show the groups which he belongs                                              #
  #     - if Group_By is agent, we show agents belonging to those groups                                         #
  # Unassigned will not be shown for an agent with restricted scope                                              #
  ################################################################################################################


  #This method takes DB id, value pairs and converts them into name => value pairs
  #nil value case is also handled and converted to 0 as value
  def map_id_to_names(response_hash)
    statuses_list = status_list_from_cache
    #this step is to form a hash of group/agent/agent groups to check if agent belongs to the group
    build_group_by_list
    result_array = group_by_values.inject([]) do |result_arr, group_value|
      result_hash = [group_value.first]
      result_hash << statuses_list.inject([]) do |res_arr, status_value|
        res_arr << (response_hash[[group_value.first, status_value.first]] || 0)
      end

      sum_value   = result_hash.last.sum
      result_arr << ((sum_value.zero? and !valid_row?(group_value.first)) ? [] : [result_hash, sum_value].flatten)
    end
    return result_array.reject(&:empty?) if !@filter_condition.blank? || current_user.assigned_ticket_permission

    #Handle unassign case - special case to put it as a separate row in response array to UI.
    mapped_status_arr = statuses_list.inject(["unassigned"]) do |status_arr,status_list|
      status_arr << (response_hash[[nil, status_list.first]] || 0)
    end

    mapped_status_arr << mapped_status_arr.map(&:to_i).sum
    result_array.insert(0, mapped_status_arr).reject(&:empty?)
  end

  def id_name_mapping(response_hash, name_mapping_key)
    name_mapping_values = case name_mapping_key
      when :status
        status_list_from_cache
      when :priority
        TicketConstants::PRIORITY_NAMES_BY_KEY
      when :group_id
        groups_list
      when :responder_id
        agents_list(true)
      when :ticket_type
        ticket_types_list
    end

    result_arr = name_mapping_values.inject([]) do |res_arr, name_map|
      res_arr << {:name => name_map.last.to_s.camelize, :value => response_hash[name_map.first].to_i, :id => name_map.first}
    end
    #a way to check for unassigned group by value
    if response_hash.has_key?(nil)
      result_arr << {:name => "Unassigned", :value => response_hash[nil], :id => "-1"}
    end

    result_arr.sort_by {|x| x[:value]}.reverse
  end

  private 

  def group_by_values
    (@group_by == "responder_id") ? agents_list : groups_list
  end

  def ticket_types_list
    current_account.ticket_types_from_cache.collect { |g| [g.value, g.value]}.to_h
  end

  def agents_list(from_dashboard = false)
    agents = agent_list_from_cache
    if from_dashboard and @group_id.present?
      groups = current_account.groups.where(:id => @group_id)
      filtered_agent_list ={}
      groups.each do |group|
        filtered_agent_list.merge!(group.agents.collect {|u| [u.id, u.name] }.to_h)
      end
      return filtered_agent_list
    end

    if @responder_id.blank?
      if current_user.assigned_ticket_permission
        {current_user.id => current_user.name}
      elsif current_user.group_ticket_permission
        agent_ids = current_account.agent_groups.where(:group_id => user_agent_groups).pluck(:user_id).uniq
        agent_ids.inject({}) do |agent_hash, agent_id|
          agent_hash.merge!({agent_id => agents[agent_id]})
        end
      else
        agents
      end
    else
      filter_list(agents, @responder_id)
    end
  end

  def groups_list
    if @group_id.blank?
      if current_user.restricted?
        group_ids = current_account.groups.select("id,name").where(id: user_agent_groups)
        group_ids.inject({}) do |group_hash, group|
          group_hash.merge!(group.id => group.name)
        end
      else
        group_list_from_cache
      end
    else
      filter_list(group_list_from_cache, @group_id)
    end
  end

  def status_list_from_cache
    statuses = Helpdesk::TicketStatus.status_names_from_cache(Account.current).to_h
    statuses.delete_if {|st| [Helpdesk::Ticketfields::TicketStatus::RESOLVED, Helpdesk::Ticketfields::TicketStatus::CLOSED].include?(st)}
    filter_list(statuses, @status)
  end

  def group_list_from_cache
    Account.current.groups_from_cache.collect { |g| [g.id, g.name]}.to_h
  end

  def agent_list_from_cache
    Account.current.agents_details_from_cache.collect { |au| [au.id, au.name] }.to_h
  end

  def filter_list(values, retain_values)
    return values if retain_values.blank?
    values.keep_if {|x| retain_values.map(&:to_i).include?(x)}
  end

  def user_agent_groups
    @user_agent_groups ||= begin
      agent_groups = User.current.agent_groups.pluck(:group_id)
      agent_groups.empty? ? [-2] : agent_groups        
    end    
  end

  #Check if the agent belongs to the selected group or not
  #Check if group has the selected agent or not
  def valid_row?(group_by_id)
    if (@group_by == "group_id" and @responder_id.present?) or (@group_by == "responder_id" and @group_id.present?)
      @group_by_list.include?(group_by_id)
    else
      true
    end
  end

  def build_group_by_list
    @group_by_list = if @group_by == "group_id" and @responder_id.present?
       current_account.agent_groups.where("user_id in (?)", @responder_id).pluck(:group_id).uniq
    elsif @group_by == "responder_id" and @group_id.present?
      current_account.agent_groups.where("group_id in (?)", @group_id).pluck(:user_id).uniq
    else
      []
    end
  end
end