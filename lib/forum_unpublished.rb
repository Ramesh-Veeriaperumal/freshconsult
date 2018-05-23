class ForumUnpublished < Dynamo

	include ForumSpamMethods

	before_save :set_timestamp, :save_changes

	after_save :into_next_month, :update_counter

	after_destroy :decr_counter, :destroy_next

	def self.table_name
		"forum_unpublished_#{Rails.env[0..3]}_#{Time.now.utc.strftime('%Y_%m')}"
	end

	def next_table
		ForumUnpublishedNext
	end

	def next
		ForumUnpublishedNext.find(:account_id => self[:account_id], :timestamp => self[:timestamp])
	end

	def type
		:unpublished
	end

end