class ForumUnpublishedNext < Dynamo

	include ForumSpamMethods

	before_save :set_timestamp, :save_changes

	after_save :update_counter

	after_destroy :decr_counter

	def self.table_name
		"forum_unpublished_#{Rails.env[0..3]}_#{(Time.now + 1.months).utc.strftime('%Y_%m')}"
	end

	def type
		:unpublished
	end

	def counter
		date = time.strftime('%Y_%m_%d')
		SpamCounterNext.for(self.type, date)
	end
end
