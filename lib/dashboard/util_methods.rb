module Dashboard::UtilMethods
  FILTER_DELIMITER = "::"

  ################################################################################################################
  # Method:: groups_list_from_cache and agent_list_from_cache                                                    #
  # If all tickets admin, then all the groups/agents will be shown if there is no filter_condition               #
  # If group access/ restricted admin, then if group by group, groups which he belongs to will be shown          #
  # If group access admin, then if group by agent, then agents belonging to those groups                         #
  # that he belongs to will be returned                                                                          #
  # Unassigned will not be shown for restricted admin                                                            #
  ################################################################################################################


  #This method takes DB id , value pairs and converts them into name => value pairs
  #nil value case is also handled and converted to 0 as value
  def map_id_to_names(ticket_hash)
    response_hash = ticket_hash.dup
    group_by_values_from_cache.merge!(0 => "Total")
    statuses_list = status_list_from_cache
    #this step is to form a hash of group/agent/agent groups to check if agent belongs to the group
    form_agent_group_data
    result_array = group_by_values_from_cache.inject([]) do |result_arr, group_value|
      result_hash = ["#{group_value.last}#{FILTER_DELIMITER}#{group_value.first}"]
      result_hash << statuses_list.inject([]) do |res_arr, status_value|
        res_arr << (response_hash[[group_value.first,status_value.first]] || 0)
      end
      sum_value = result_hash.last.sum
      if sum_value.zero?
        if valid_row?(group_value.first)
          result_arr << [result_hash,sum_value].flatten
        else
          result_arr << []
        end
      else
        result_arr << [result_hash,sum_value].flatten
      end
    end
    return result_array.reject(&:empty?) if !@filter_condition.blank? || current_user.assigned_ticket_permission
    #Handle unassign case - special case to put it as a separate row in respose array to UI.
    mapped_status_arr = statuses_list.inject(["Unassigned#{FILTER_DELIMITER}unassigned"]) do |status_arr,status_list|
      status_arr << (response_hash[[nil,status_list.first]] || 0)
    end
    mapped_status_arr << mapped_status_arr.map(&:to_i).sum
    result_array.insert(0,mapped_status_arr).reject(&:empty?)
  end

  def group_by_values_from_cache
    (@group_by == "responder_id") ? agents_list_from_cache : group_list_from_cache
  end

  def agents_list_from_cache
    agents = Account.current.agents_from_cache.collect { |au| [au.user_id, au.user.name] }.to_h
    unless @filter_condition.present?
      if current_user.assigned_ticket_permission
        {current_user.id => current_user.name}
      elsif current_user.group_ticket_permission
        agent_ids = current_account.agent_groups.where(:group_id => @user_agent_groups).pluck(:user_id).uniq
        agent_ids.inject({}) do |agent_hash, agent_id|
          agent_hash.merge!({agent_id => agents[agent_id]})
        end
      else
        agents
      end
    else
      strip_data(agents,@responder_id)
    end
  end

  def group_list_from_cache
    groups = Account.current.groups_from_cache.collect { |g| [g.id, g.name]}.to_h
    unless @filter_condition.present?
      if current_user.restricted?
        group_ids = current_account.groups.select("id,name").where(id:@user_agent_groups)
        group_ids.inject({}) do |group_hash, group|
          group_hash.merge!(group.id => group.name)
        end
      else
        groups
      end
    else
      strip_data(groups,@group_id)
    end
  end

  def status_list_from_cache
    statuses = Helpdesk::TicketStatus.status_names_from_cache(Account.current).to_h
    statuses.delete_if {|st| [Helpdesk::Ticketfields::TicketStatus::RESOLVED,Helpdesk::Ticketfields::TicketStatus::CLOSED].include?(st)}
    strip_data(statuses, @status)
  end

  def strip_data(values, to_be_stripped)
    return values if to_be_stripped.blank?
    values.delete_if {|x| !to_be_stripped.map(&:to_i).include?(x)}
  end

  def user_agent_groups
    agent_groups = User.current.agent_groups.select(:group_id).map(&:group_id).map(&:to_s)
    agent_groups.empty? ? ["-2"] : agent_groups
  end

  #Check if the agent belongs to the selected group or not
  #Check if group has the selected agent or not
  def valid_row?(group_value_id)
    if @group_by == "group_id" and @responder_id.present?
      @group_list.include?(group_value_id)
    elsif @group_by == "responder_id" and @group_id.present?
      @agent_list.include?(group_value_id)
    else
      true
    end
  end

  def form_agent_group_data
    @group_list = []
    @agent_list = []
    if @group_by == "group_id" and @responder_id.present?
      @group_list = current_account.agent_groups.select(:group_id).where("user_id in (?)", @responder_id).map(&:group_id).uniq
    elsif @group_by == "responder_id" and @group_id.present?
      @agent_list = current_account.agent_groups.select(:user_id).where("group_id in (?)", @group_id).map(&:user_id).uniq
    end
  end
end