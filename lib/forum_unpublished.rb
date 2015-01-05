class ForumUnpublished < Dynamo

	include ForumSpamMethods

	before_save :set_timestamp, :save_changes

	after_save :into_next_month, :update_counter

	after_destroy :decr_counter, :destroy_next

	def self.table_name
		"forum_unpublished_#{RAILS_ENV[0..3]}_#{Time.now.utc.strftime('%Y_%m')}"
	end

	def next_table
		ForumUnpublishedNext
	end

	def self.by_user(acc, user, user_timestamp)
		query(
			:account_id => acc,
			:user_timestamp => 
			[:between, user_timestamp, next_user_timestamp(user)],
			:ascending => true
			)
	end

	def next
		ForumUnpublishedNext.find(:account_id => self[:account_id], :timestamp => self[:timestamp])
	end

	def type
		:unpublished
	end

	def self.next_user_timestamp(user)
		(user + 1) * 10.power!(17) + Time.now.utc.to_f * 10.power!(7)
	end


end