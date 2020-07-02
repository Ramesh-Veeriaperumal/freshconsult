class Group < ActiveRecord::Base

  def round_robin_actions
    if transaction_include_action?(:create)
      create_round_robin_list if round_robin_enabled?
      trigger_capping
    elsif transaction_include_action?(:update)
      update_round_robin_list
      trigger_capping
    elsif transaction_include_action?(:destroy)
      remove_round_robin_data(@user_ids)
    end
  end

  def remove_round_robin_data user_ids
    delete_round_robin_list
    shutdown_capping(user_ids) if round_robin_capping_enabled?
  end

  def next_available_agent
    queue_length = llen_round_robin_redis(round_robin_key)
    (queue_length + RR_BUFFER).times do
      current_agent_id = get_others_redis_rpoplpush(round_robin_key, round_robin_key)
      Rails.logger.debug "CURRENT AGENT ID :: #{current_agent_id}"
      return if current_agent_id.nil?
      current_agent = account.available_agents.find_by_user_id(current_agent_id)
      Rails.logger.debug "CURRENT AGENT :: #{current_agent.inspect}"
      return current_agent if current_agent.present?
      $redis_others.lrem(round_robin_key, 0, current_agent_id)
    end
    nil
  end


  def update_agent_capping_with_lock user_id, new_score, operation="incr"
    agent_key = round_robin_agent_capping_key(user_id)
    key = round_robin_capping_key
    
    $redis_round_robin.multi do |m|
      m.zadd(key, new_score, user_id)
      m.safe_send(operation, agent_key)
    end
  end

  def update_agent_capping score, user_id
    key = round_robin_capping_key
    zadd_round_robin_redis(key, score, user_id)
  end

  def next_agent_with_capping ticket_id
    if exists_round_robin_redis(round_robin_capping_permit_key)
      MAX_CAPPING_RETRY.times do
        user_id, old_score = pick_next_agent(ticket_id)
        if user_id.present?
          ticket_count_in_redis = get_round_robin_redis(round_robin_agent_capping_key(user_id)).to_i
          status_ids = Helpdesk::TicketStatus.sla_timer_on_status_ids(account)
          db_count = tickets.visible.where('responder_id = ? and status in (?)', user_id, status_ids).count
          if account.retrigger_lbrr_enabled? && exists_round_robin_redis(round_robin_capping_permit_key) &&
             (count_mismatch?(old_score, db_count + 1, 'incr') ||
              count_mismatch?(ticket_count_in_redis, db_count + 1, 'incr'))
            Rails.logger.debug "RR count mismatch: #{old_score} #{db_count} next_agent_with_capping"
            rpush_to_rr_capping_queue(ticket_id)
            Groups::RoundRobinCapping.perform_async(group_id: id, reset_capping: true)
            return
          end
          new_score = generate_new_score(old_score + 1)
          result    = update_agent_capping_with_lock(user_id, new_score)

          if result.is_a?(Array) && result[1].present?
            Rails.logger.debug "RR SUCCESS RR assignment for ticket : #{ticket_id} - 
            #{user_id}, #{self.id}, #{status_ids.inspect}, #{new_score}, #{db_count}, #{result.inspect}".squish
            return account.agents.find_by_user_id(user_id)
          end
        else
          rpush_to_rr_capping_queue(ticket_id)
          return
        end
        Rails.logger.debug "RR FAILED RR assignment for ticket : #{ticket_id} - 
            #{user_id}, #{self.id}, #{new_score}, #{result.inspect}".squish
      end
      rpush_to_rr_capping_queue(ticket_id)
    else
      Rails.logger.debug "Redis key not exists for round robin :: group #{self.id} :: ticket #{ticket_id}"
      sadd_round_robin_redis(rr_temp_tickets_queue_key, ticket_id)
    end
    nil
  end

  def pick_next_agent ticket_id
    queue_length = zcount_round_robin_redis(round_robin_capping_key, 0, ROUND_ROBIN_MAX_SCORE)
    (queue_length + RR_BUFFER).times do
      user_score = zrange_round_robin_redis(round_robin_capping_key, 0, 0, true)
      return unless user_score.present?
      user_id = user_score[0][0].to_i
      current_agent = account.available_agents.find_by_user_id(user_id)
      old_score = nil
      if current_agent.present?
        agent_key = round_robin_agent_capping_key(user_id)
        watch_round_robin_redis(agent_key)
        old_score = get_round_robin_redis(agent_key).to_i
        old_score = old_score.to_i unless old_score.nil?

        Rails.logger.debug "RR pick_next_agent : #{user_id} #{old_score} #{user_score.inspect} #{self.capping_limit}"

        if old_score
          if old_score < self.capping_limit
            return [user_id, old_score]
          else
            break
          end
        end
      end
      remove_agent_from_group_capping(user_id) if old_score.nil?
    end
    nil
  end

  def add_agent_to_group_capping user_id
    Rails.logger.debug "add_agent_to_group_capping #{user_id} #{self.id}"
    status_ids   = Helpdesk::TicketStatus::sla_timer_on_status_ids(account)
    ticket_count = Sharding.run_on_slave { tickets.visible.agent_tickets(status_ids, user_id).count }
    new_score    = generate_new_score(ticket_count)
    
    update_agent_capping(new_score, user_id)
    set_round_robin_redis(round_robin_agent_capping_key(user_id), ticket_count)
  end

  def remove_agent_from_group_capping user_id
    Rails.logger.debug "remove_agent_from_group_capping #{user_id} #{self.id}"
    agent_key = round_robin_agent_capping_key(user_id)
    del_round_robin_redis(agent_key)
    
    capping_key = round_robin_capping_key
    begin
      zrem_round_robin_redis(capping_key, user_id)
    rescue Exception => e
      desc = "LBRR error #{user_id} #{capping_key} #{current_account.id}"
      Rails.logger.debug desc
      Rails.logger.debug "#{e.message} #{e.class} #{e.backtrace}"
      NewRelic::Agent.notice_error(e,{:description => desc})
    end
  end

  def assign_tickets agent
    self.capping_limit.times do
      break unless agent.assign_next_ticket(self)
    end
  end

  def round_robin_queue
    if skill_based_round_robin_enabled?
      []
    elsif round_robin_capping_enabled?
      res = zrange_round_robin_redis(round_robin_capping_key, 0, -1)
      res.present? ? res.reverse : []
    else
      get_others_redis_list(round_robin_key)
    end
  end

  def remove_agent_from_round_robin(user_id)
    delete_agent_from_round_robin(user_id) 
  end

  def add_or_remove_agent(user_id, add=true)
    begin
      $redis_others.multi do 
        $redis_others.lrem(round_robin_key,0,user_id)
        $redis_others.lpush(round_robin_key,user_id) if add
      end
    rescue Exception => e
      desc = "RR error #{user_id} #{round_robin_key} #{current_account.id}"
      Rails.logger.debug desc
      Rails.logger.debug "#{e.message} #{e.class} #{e.backtrace}"
      NewRelic::Agent.notice_error(e,{:description => desc})
    end
  end

  def create_round_robin_list
    user_ids = self.agent_groups.available_agents.map(&:user_id)
    set_others_redis_lpush(round_robin_key, user_ids) if user_ids.any?
  end

  def update_round_robin_list
    return unless @model_changes.key?(:ticket_assign_type)
    round_robin_enabled? ? create_round_robin_list : delete_round_robin_list
  end

  def delete_round_robin_list
    remove_others_redis_key(round_robin_key)
  end 

  def delete_agent_from_round_robin(user_id) #new key
      get_others_redis_lrem(round_robin_key, user_id)
  end

  def trigger_capping
    Groups::RoundRobinCapping.perform_async({ :group_id => self.id,
      :model_changes => @model_changes }) if trigger_lbrr?
  end

  def trigger_lbrr?
    round_robin_capping_changed? || round_robin_changed?
  end

  def round_robin_changed?
    @model_changes && @model_changes[:ticket_assign_type] && @model_changes[:ticket_assign_type].include?(TICKET_ASSIGN_TYPE[:round_robin])
  end

  def round_robin_capping_initialized?
    @model_changes[:ticket_assign_type] && @model_changes[:ticket_assign_type].last == TICKET_ASSIGN_TYPE[:round_robin]
  end

  def shutdown_capping(user_ids, reset_capping = false)
    user_ids.each do |id|
      key = round_robin_agent_capping_key(id)
      del_round_robin_redis(key)
    end
    [round_robin_capping_key, round_robin_capping_permit_key,
     rr_temp_tickets_queue_key, rr_tickets_default_zset_key].each do |key|
      del_round_robin_redis(key)
    end
    del_round_robin_redis(round_robin_tickets_key) unless reset_capping
  end

  def round_robin_capping_changed?
    @model_changes && @model_changes.key?(:capping_limit) && round_robin? && Account.current.round_robin_capping_enabled?
  end

  def round_robin?
    (ticket_assign_type == TICKET_ASSIGN_TYPE[:round_robin]) 
  end

  def round_robin_enabled?
    (ticket_assign_type == TICKET_ASSIGN_TYPE[:round_robin]) and Account.current.features?(:round_robin)
  end

  def lbrr_enabled?
    round_robin_enabled? && capping_enabled?
  end

  def capping_enabled?
    self.capping_limit > 0 if self.capping_limit.present?
  end

  def round_robin_capping_enabled?
    capping_enabled? && Account.current.round_robin_capping_enabled?
  end  
  
  def round_robin_key
    GROUP_ROUND_ROBIN_AGENTS % { :account_id => self.account_id, 
                               :group_id => self.id}
  end

  def round_robin_capping_key
    ROUND_ROBIN_CAPPING % { :account_id => self.account_id, :group_id => self.id }
  end

  def round_robin_tickets_key
    RR_CAPPING_TICKETS_QUEUE % { :account_id => self.account_id, :group_id => self.id }
  end

  def rr_temp_tickets_queue_key
    RR_CAPPING_TEMP_TICKETS_QUEUE % { :account_id => self.account_id, :group_id => self.id }
  end

  def round_robin_capping_permit_key
    ROUND_ROBIN_CAPPING_PERMIT % { :account_id => self.account_id, :group_id => self.id }
  end

  def round_robin_agent_capping_key(user_id)
    ROUND_ROBIN_AGENT_CAPPING % { :account_id => self.account_id, :group_id => self.id, :user_id => user_id }
  end

  def rr_tickets_default_zset_key
    RR_CAPPING_TICKETS_DEFAULT_SORTED_SET % { :account_id => self.account_id, :group_id => self.id }
  end



  def lpush_to_rr_capping_queue ticket_id
    Rails.logger.debug "lpush_to_rr_capping_queue #{ticket_id} #{self.id}"
    update_sorted_set("lpush", ticket_id)
    lpush_round_robin_redis(round_robin_tickets_key, ticket_id)
  end

  def rpush_to_rr_capping_queue ticket_id
    update_sorted_set("rpush", ticket_id)
    rpush_round_robin_redis(round_robin_tickets_key, ticket_id)
    rr_tickets_key_length = count_unassigned_tickets_in_group
    Rails.logger.debug "RR SUCCESS Added ticket to unassigned queue : #{ticket_id} 
                        #{self.id} : count=#{rr_tickets_key_length} : #{list_unassigned_tickets_in_group(rr_tickets_key_length).inspect}".squish
  end

  def lpop_from_rr_capping_queue
    update_sorted_set("lpop")
    lpop_round_robin_redis(round_robin_tickets_key)
  end

  def lrem_from_rr_capping_queue ticket_id
    Rails.logger.debug "lrem_from_rr_capping_queue #{ticket_id} #{self.id}"
    update_sorted_set("lrem", ticket_id)
    lrem_round_robin_redis(round_robin_tickets_key, ticket_id)
  end

  # Method for logging
  def list_capping_range
    arr = []
    zrange_round_robin_redis(round_robin_capping_key, 0, -1, true).each do |val|
      arr.push([val[0], get_round_robin_redis(round_robin_agent_capping_key(val[0]))])
    end
    arr
  end

  # Method for logging
  def list_unassigned_tickets_in_group(end_index = MAX_FETCH_TICKETS_COUNT)
    end_index = [MAX_FETCH_TICKETS_COUNT, end_index].min
    lrange_round_robin_redis(round_robin_tickets_key, 0, end_index)
  end
  
  # Method for logging
  def count_unassigned_tickets_in_group
    llen_round_robin_redis(round_robin_tickets_key)
  end
  
  private
    def sorted_set_ticket_score
      Time.now.utc.to_i
    end

    def sorted_set_ticket_score_for_lpush
      res = zrange_round_robin_redis(rr_tickets_default_zset_key, 0, 0, true)[0]
      res.present? ? (res[1].to_i - 1) : sorted_set_ticket_score
    end

    def zadd_to_sorted_set operation, ticket_id
      score = operation=="rpush" ? sorted_set_ticket_score : 
                                   sorted_set_ticket_score_for_lpush
      zadd_round_robin_redis(rr_tickets_default_zset_key, score, ticket_id)
    end

    def update_sorted_set operation, ticket_id=nil
      if ticket_id.present?
        if ticket_id.is_a?(Array)
          ticket_id.each do |id|
            zadd_to_sorted_set(operation, id)
          end
        else
          operation=="lrem" ? zrem_round_robin_redis(rr_tickets_default_zset_key, ticket_id) : 
                              zadd_to_sorted_set(operation, ticket_id)
        end
      else
        if operation=="lpop"
          res = zrange_round_robin_redis(rr_tickets_default_zset_key, 0, 0, true)[0]
          zrem_round_robin_redis(rr_tickets_default_zset_key, res[0]) if res.present?
        end
      end
    rescue Exception => e
      Rails.logger.debug "Exception while updating sorted set : #{e.message}"
    end

    def new_round_robin_key
      GROUP_ROUND_ROBIN_AGENTS % { :account_id => self.account_id, 
                                 :group_id => self.id}
    end

    def reset_toggle_availability
      if ticket_assign_type == TICKET_ASSIGN_TYPE[:default]
        toggle_availability = false unless Account.current.agent_statuses_enabled?
        capping_limit = 0
      end
      true
    end
end
