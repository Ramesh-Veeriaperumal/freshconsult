class SpamCounterNext < Dynamo

	include SpamCounterMethods

	def self.table_name
		"spam_counter_#{Rails.env[0..3]}_#{(Time.now + 1.months).utc.strftime('%Y_%m')}"
	end
end
