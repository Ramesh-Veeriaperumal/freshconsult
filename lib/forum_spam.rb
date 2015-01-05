class ForumSpam < Dynamo

	UPTO = (31.days).to_i

	include ForumSpamMethods

	before_save :set_timestamp, :save_changes

	after_save :into_next_month, :update_counter

	after_destroy :decr_counter, :destroy_next

	def self.table_name
		"forum_spam_#{RAILS_ENV[0..3]}_#{Time.now.utc.strftime('%Y_%m')}"
	end

	def next_table
		ForumSpamNext
	end

	def self.delete_account_spam(acc)
		results = ForumSpam.query(:account_id => acc)
		while(results.present?)
			last_time = results.last.timestamp
			results.each do |result|
				result.destroy
			end
			results = ForumSpam.query(:account_id => acc, :timestamp => [:lt, last_time])
		end
	end

	def next
		ForumSpamNext.find(:account_id => self[:account_id], :timestamp => self[:timestamp])
	end

	def type
		:spam
	end
end
