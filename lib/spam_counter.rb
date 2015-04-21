class SpamCounter < Dynamo

	include SpamCounterMethods

	def self.table_name
		"spam_counter_#{Rails.env[0..3]}_#{Time.now.utc.strftime('%Y_%m')}"
	end

	def next_counter
		@next_counter ||= SpamCounterNext.for(:account_id => self[:account_id], :type_and_date => self[:type_and_date])
	end

	def self.count(topic_id, type, account_id)
		counters = find_counters(type, account_id, topic_id)
		topic_count(topic_id, counters)
	end

	def self.topic_count(topic_id, counters)
		counters.collect {|c| c.attributes[topic_id.to_s].to_i }.compact.inject(:+) || 0
	end

	def self.elaborate_count(account_id, type)
		excluded_keys = all_keys.map {|m| m[:name]}.push("0")
		counters = find_counters(type, account_id)
		total_count = topic_count(0, counters)
		posts_count = (
			counters.inject(0) do |m,c|
				counter = c.attributes.delete_if { |k,v| excluded_keys.include?(k)}
				m = m + counter.values.map(&:to_i).sum 
			end
		)
		{ :topics => total_count - posts_count , :posts => posts_count }
	end
		
	def self.find_counters(type, account_id, select=nil)
		query_hash = {
			:account_id => account_id, 
			:type_and_date => conditions_arr(type),
			:limit => (ForumSpam::UPTO / 1.days.to_i)
		}
		query_hash.merge!({:select => [select.to_s]}) unless select.blank?
		query(query_hash).records
	end

	def self.conditions_arr(type)
		[ :between, %{#{type}_#{(Time.now - ForumSpam::UPTO).utc.strftime('%Y_%m_%d')}}, 
									%{#{type}_#{Time.now.utc.strftime('%Y_%m_%d')}} ]
	end

	def self.spam_count account_id
		count(0, "spam", account_id)
	end

	def self.unpublished_count account_id
		count(0, "unpublished", account_id)
	end
end