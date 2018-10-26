module SlaSidekiq
  include Redis::RedisKeys
  include Redis::OthersRedis

  def tickets_limit
    # SLA_TICKETS_LIMIT redis key holds the max number of tickets that can be pick in a single rake job
    # To bypass this max limit check, use 'whitelist_supervisor_sla_limitation' launch party feature
    @tickets_limit ||= get_others_redis_key(SLA_TICKETS_LIMIT).to_i unless Account.current.whitelist_supervisor_sla_limitation_enabled?
  end

  def tickets_limit_check(total_tickets, tickets_count)
    tickets_limit && (total_tickets + tickets_count > tickets_limit)
  end

  def log_tickets_limit_exceeded(account_id, ticket_id, escalation_type, total_tickets_executed, sla_type)
    Rails.logger.debug "SLA #{sla_type}: Tickets limit exceeded at type=#{escalation_type}, 
    account_id=#{account_id}, exceeded_ticket_id=#{ticket_id}, 
    total_tickets_executed=#{total_tickets_executed}".squish
  end

end
