module SpamCounterMethods
	TYPES = [:spam, :unpublished]

	def self.included(base)
		base.extend(ClassMethods)
		base.send(:include, Community::Moderation::ForumSpamTables)
		base.hash_key(:account_id, :n)
		base.range(:type_and_date, :s)
		base.provisioned_throughput(base.inactive_capacity, base.write_capacity)
	end

	def account
		return nil unless self[:account_id].present?
		Account.find(self[:account_id])
	end

	def type
		self[:type_and_data].split("_").first.to_sym if self[:type_and_data].present?
	end

	def date
		Time.parse(self[:type_and_data].gsub("#{type}_")).utc if self[:type_and_data].present?
	end

	def incr_topic!(topic_id)
		incr!(topic_id.to_i, 0)
	end

	def incr_new_topic!
		incr!(0)
	end

	def decr_topic!(topic_id)
		decr!(topic_id.to_i, 0)
	end

	def decr_new_topic!
		decr!(0)
	end

	def total
		total = @attributes["0"]
		total < 0 ? 0 : total unless total.nil?
	end

	module ClassMethods

		def for(type, date = Time.now.utc.strftime('%Y_%m_%d'))
			type = TYPES.include?(type) ? type : TYPES.first
			find_or_initialize(:account_id => Account.current.id, :type_and_date => "#{type}_#{date}")
		end
	end
end