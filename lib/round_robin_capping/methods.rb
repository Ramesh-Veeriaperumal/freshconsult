module RoundRobinCapping::Methods

  include Redis::RoundRobinRedis

  MAX_CAPPING_RETRY         = 10
  ROUND_ROBIN_DEFAULT_SCORE = 10**15
  ROUND_ROBIN_MAX_SCORE     = 200 * 10**15
  RR_BUFFER                 = 5
  MAX_FETCH_TICKETS_COUNT   = 100

  def generate_new_score tickets_count, timestamp = nil
    tickets_count = 0 if tickets_count < 0
    timestamp ||= Time.now.utc.to_i
    ROUND_ROBIN_DEFAULT_SCORE*(tickets_count) + timestamp
  end

  def count_mismatch?(ticket_count, db_count, operation)
    (ticket_count < 0) ||
      (ticket_count.zero? && (operation == 'decr')) ||
      ((db_count + 1 != ticket_count) && (operation == 'decr')) ||
      ((db_count - 1 != ticket_count) && (operation == 'incr'))
  end

  def agents_ticket_count score
    (score/ROUND_ROBIN_DEFAULT_SCORE).to_i
  end

  def last_assigned_timestamp score
    (score % ROUND_ROBIN_DEFAULT_SCORE).to_i
  end

  def capping_enabled?
    @capping_limit_change.is_a?(Array) && @capping_limit_change[0] == 0
  end

  def capping_increased?
    @capping_limit_change.is_a?(Array) && @capping_limit_change[1] > @capping_limit_change[0]
  end

  def lbrr_init?
    @model_changes[:ticket_assign_type] && @model_changes[:ticket_assign_type].last == Group::TICKET_ASSIGN_TYPE[:round_robin]
  end

end
