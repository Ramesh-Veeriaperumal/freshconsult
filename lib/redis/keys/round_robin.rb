module Redis::Keys::RoundRobin
  
  GROUP_ROUND_ROBIN_AGENTS              = "GROUP_ROUND_ROBIN_AGENTS:%{account_id}:%{group_id}".freeze
  # LBRR
  ROUND_ROBIN_CAPPING                   = "ROUND_ROBIN_CAPPING:%{account_id}:%{group_id}".freeze
  ROUND_ROBIN_CAPPING_PERMIT            = "ROUND_ROBIN_CAPPING_PERMIT:%{account_id}:%{group_id}".freeze
  ROUND_ROBIN_AGENT_CAPPING             = "ROUND_ROBIN_AGENT_CAPPING:%{account_id}:%{group_id}:%{user_id}".freeze
  RR_CAPPING_TICKETS_QUEUE              = "RR_CAPPING_TICKETS_QUEUE:%{account_id}:%{group_id}".freeze
  RR_CAPPING_TEMP_TICKETS_QUEUE         = "RR_CAPPING_TEMP_TICKETS_QUEUE:%{account_id}:%{group_id}".freeze
  RR_CAPPING_TICKETS_DEFAULT_SORTED_SET = "RR_CAPPING_TICKETS_DEFAULT_SORTED_SET:%{account_id}:%{group_id}".freeze
  # SBRR
  SKILL_BASED_TICKETS_SORTED_SET        = "SKILL_BASED_TICKETS_SORTED_SET:%{account_id}:%{group_id}:%{skill_id}".freeze
  SKILL_BASED_TICKETS_LOCK_KEY          = "SKILL_BASED_TICKETS_LOCK_KEY:%{account_id}:%{ticket_id}".freeze
  SKILL_BASED_USERS_SORTED_SET          = "SKILL_BASED_USERS_SORTED_SET:%{account_id}:%{group_id}:%{skill_id}".freeze
  SKILL_BASED_USERS_LOCK_KEY            = "SKILL_BASED_USERS_LOCK_KEY:%{account_id}:%{group_id}:%{user_id}".freeze
end