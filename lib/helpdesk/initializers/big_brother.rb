module BigBrother
	
	def record_stats
		if self.respond_to?(:account_id)
			camel_to_table = self.class.to_s.gsub("::","").tableize
			shard_name = ActiveRecord::Base.current_shard_selection.shard
			$statsd.increment "#{shard_name}.model.#{camel_to_table}.#{account_id}"
		end
	end

	def self.included(receiver)
			receiver.after_commit_on_create :record_stats
	end
end

ActiveRecord::Base.send :include, BigBrother