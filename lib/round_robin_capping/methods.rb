module RoundRobinCapping::Methods

  include Redis::RoundRobinRedis

  MAX_CAPPING_RETRY         = 10
  ROUND_ROBIN_DEFAULT_SCORE = 10**15

  def generate_new_score score
    score <= 0 ? 0 : ROUND_ROBIN_DEFAULT_SCORE*(score) + Time.now.utc.to_i
  end

  def agents_ticket_count score
    (score/ROUND_ROBIN_DEFAULT_SCORE).to_i
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
