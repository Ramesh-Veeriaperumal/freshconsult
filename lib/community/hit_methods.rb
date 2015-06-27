module Community::HitMethods

	extend ActiveSupport::Concern

	def hit!
		current_klass = self.class
		new_count = increment_others_redis(hit_key)
		if new_count >= current_klass::HITS_CACHE_THRESHOLD
			total_hits = read_attribute(:hits) + current_klass::HITS_CACHE_THRESHOLD
			self.update_column(:hits, total_hits)
			decrement_others_redis(hit_key, current_klass::HITS_CACHE_THRESHOLD)
		end
		self.meta_object.hit! if self.respond_to?(:meta_association)
		true
	end

	def hits
		get_others_redis_key(hit_key).to_i + self.read_attribute(:hits)
	end
end