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
end
