class ForumSpamNext < Dynamo

	include ForumSpamMethods

	before_save :set_timestamp, :save_changes

	after_save :update_counter

	after_destroy :decr_counter

	def self.table_name
		"forum_spam_#{RAILS_ENV[0..3]}_#{(Time.now + 1.months).utc.strftime('%Y_%m')}"
	end

	def type
		:spam
	end

	def counter
		date = time.strftime('%Y_%m_%d')
		SpamCounterNext.for(self.account_id, self.type, date)
	end
end
