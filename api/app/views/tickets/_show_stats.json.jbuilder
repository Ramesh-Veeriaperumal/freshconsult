if @stats
  json.stats do
    json.cache! CacheLib.key(@stats, params) do
      json.set! :resolved_at, @stats.resolved_at.try(:utc)
      json.set! :first_responded_at, @stats.first_response_time.try(:utc)
      json.set! :closed_at, @stats.closed_at.try(:utc)
    end
  end
else
  json.set! :stats, {}
end
