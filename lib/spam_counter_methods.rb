module SpamCounterMethods

	include Community::Moderation::Constants

	TYPES = [:spam, :unpublished]

	def self.included(base)
		base.extend(ClassMethods)
		base.include(Community::Moderation::ForumSpamTables)
		base.hash_key(:account_id, :n)
		base.range(:type_and_date, :s)
		base.provisioned_throughput(DYNAMO_THROUGHPUT[:inactive], DYNAMO_THROUGHPUT[:write])
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
		@attributes["0"]
	end

	module ClassMethods

		def for(account_id, type, date = Time.now.utc.strftime('%Y_%m_%d'))
			type = TYPES.include?(type) ? type : TYPES.first
			find_or_initialize(:account_id => account_id, :type_and_date => "#{type}_#{date}")
		end
	end
end