module Community::HitMethods

	extend ActiveSupport::Concern

	def hit!
		current_klass = self.class
		new_count = increment_others_redis(hit_key)
		if new_count >= current_klass::HITS_CACHE_THRESHOLD
			self.class.update_counters(self.id, :hits => current_klass::HITS_CACHE_THRESHOLD)
			decrement_others_redis(hit_key, current_klass::HITS_CACHE_THRESHOLD)
		end
		return true unless self.respond_to?(:meta_association)
		self.meta_object.hit! unless self.meta_object.new_record?
		true
	end

	def hits
		get_others_redis_key(hit_key).to_i + self.read_attribute(:hits)
	end
end
