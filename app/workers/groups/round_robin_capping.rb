class Groups::RoundRobinCapping < BaseWorker
  
  sidekiq_options :queue => :round_robin_capping, 
                  :retry => 0, 
                  :backtrace => true, 
                  :failures => :exhausted

  include Redis::RoundRobinRedis
  include RoundRobinCapping::Methods
  
  def perform(args)
    args.symbolize_keys!
    Sharding.run_on_slave do 
      group = Account.current.groups.find_by_id(args[:group_id])
      capping_limit_change = args[:capping_limit_change]

      if group.capping_enabled?
        group.delete_round_robin_list
        if capping_limit_change[0] == 0
          init_capping(group)
        elsif capping_limit_change[1] > capping_limit_change[0]
          rebalance_capping(group)
        end
      else
        group.shutdown_capping(group.agents.pluck(:user_id))
        group.create_round_robin_list if group.round_robin_enabled?
      end
    end
  end

  def init_capping group
    user_ids = group.agent_groups.available_agents.pluck(:user_id)
    if user_ids.present?
      key = group.round_robin_capping_key
      status_ids = Helpdesk::TicketStatus::sla_timer_on_status_ids(Account.current)
      user_ids.each do |u_id|
        ticket_count = group.tickets.visible.agent_tickets(status_ids, u_id).count
        new_score    = generate_new_score(ticket_count)
        group.update_agent_capping(new_score, u_id)
        set_round_robin_redis(group.round_robin_agent_capping_key(u_id), ticket_count)
      end

      capping_reached = false
      latest_ticket = group.tickets.visible.unassigned.sla_on_tickets(status_ids).last
      last_ticket_id = latest_ticket.id if latest_ticket.present?
      if last_ticket_id
        group.tickets.visible.unassigned.sla_on_tickets(status_ids).where("id <= '#{last_ticket_id}'").find_each do |ticket|
          capping_reached = assign_ticket(group, ticket, key)
          break if capping_reached
        end
      end

      set_round_robin_redis(group.round_robin_capping_permit_key, 1)

      if capping_reached
        ticket_ids = []
        ticket_ids = group.tickets.visible.unassigned.sla_on_tickets(status_ids).where("id <= '#{last_ticket_id}'").pluck(:display_id) if last_ticket_id
        ticket_ids += smembers_round_robin_redis(group.rr_temp_tickets_queue_key).map(&:to_i)
        group.lpush_to_rr_capping_queue(ticket_ids.reverse) if ticket_ids.present?
      else
        handle_temp_tickets(group, key)
      end
    else
      status_ids = Helpdesk::TicketStatus::sla_timer_on_status_ids(Account.current)
      ticket_ids = group.tickets.visible.unassigned.sla_on_tickets(status_ids).pluck(:display_id)
      group.lpush_to_rr_capping_queue(ticket_ids.reverse) if ticket_ids.present?
      set_round_robin_redis(group.round_robin_capping_permit_key, 1)
      temp_ticket_ids = smembers_round_robin_redis(group.rr_temp_tickets_queue_key).map(&:to_i)
      group.rpush_to_rr_capping_queue(temp_ticket_ids) if temp_ticket_ids.present?
    end
  end
  
  def rebalance_capping group
    del_round_robin_redis(group.round_robin_capping_permit_key)
    
    key = group.round_robin_capping_key
    capping_reached = false
    loop do
      ticket_id = group.lpop_from_rr_capping_queue
      break unless ticket_id
      ticket = group.tickets.visible.find_by_display_id(ticket_id)
      capping_reached = assign_ticket(group, ticket, key) if ticket.present?
      if capping_reached
        group.lpush_to_rr_capping_queue(ticket_id)
        break
      end
    end

    set_round_robin_redis(group.round_robin_capping_permit_key, 1)

    if capping_reached
      ticket_ids = smembers_round_robin_redis(group.rr_temp_tickets_queue_key).map(&:to_i)
      group.rpush_to_rr_capping_queue(ticket_ids.reverse) if ticket_ids.present?
    else
      handle_temp_tickets(group, key)
    end
  end

  def handle_temp_tickets group, key
    ids = smembers_round_robin_redis(group.rr_temp_tickets_queue_key).map(&:to_i)
    group.tickets.visible.where(["id in (?)", ids]).find_each do |ticket|
      if assign_ticket(group, ticket, key)
        latest_ids = smembers_round_robin_redis(group.rr_temp_tickets_queue_key).map(&:to_i)
        group.tickets.visible.where(["id in (?)", latest_ids]).find_each do |ticket|
          latest_ids.delete(ticket.display_id) unless ticket.capping_ready?
        end
        group.lpush_to_rr_capping_queue(latest_ids.reverse)
        break
      else
        srem_round_robin_redis(group.rr_temp_tickets_queue_key, ticket.display_id)
      end
    end
  end

  def assign_ticket group, ticket, key
    user_id, old_score = group.pick_next_agent(ticket.display_id)

    if user_id.present? && ticket.capping_ready?
      Sharding.run_on_master do 
        ticket.responder_id = user_id
        ticket.set_round_robin_activity
        ticket.save
      end
      false
    else
      true
    end
  end
end
