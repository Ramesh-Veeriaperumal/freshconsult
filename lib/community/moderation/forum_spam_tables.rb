module Community::Moderation::ForumSpamTables

	MONTHS_SINCE = {
		:previous => -1,
		:afternext => 2	
	}

	def self.included(base)
		base.extend(ClassMethods)
	end

	module ClassMethods

		MONTHS_SINCE.each_pair do |method_name, months|
			define_method(method_name) do
				prefix = table_name.split(Rails.env[0..3]).first
				%{#{prefix}#{Rails.env[0..3]}_#{(Time.now.months_since(months)).utc.strftime('%Y_%m')}}
			end

			define_method(%{#{method_name.to_s}_year}) do
				Time.now.months_since(months).year
			end

			define_method(%{#{method_name.to_s}_month}) do
				Time.now.months_since(months).month
			end
		end
	end
end