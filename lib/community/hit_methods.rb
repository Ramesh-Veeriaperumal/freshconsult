module Community::HitMethods

	extend ActiveSupport::Concern

	def hit!
		current_klass = self.class
		new_count = increment_others_redis(hit_key)
		flush_hits(current_klass::HITS_CACHE_THRESHOLD) if new_count >= current_klass::HITS_CACHE_THRESHOLD
		return true unless self.respond_to?(:language)
		self.parent.hit!
    manual_publish_interaction(:incr, :hits)
		true
	end

  def flush_hits!
    count = get_others_redis_key(hit_key).to_i
    flush_hits(count)
    return true unless self.respond_to?(:language)
    self.parent.flush_hits!
    true
  end

  def flush_hits(count)
    self.class.update_counters(self.id, :hits => count)
    version_hit(count)
    decrement_others_redis(hit_key, count)
  end

  def version_hit(count)
    self.live_version.class.update_counters(self.live_version.id, :hits => count) if self.account.article_versioning_enabled? && (self.instance_of? Solution::Article) && self.live_version
  end

	def hits
		@hits ||= get_others_redis_key(hit_key).to_i + self.read_attribute(:hits)
	end
end