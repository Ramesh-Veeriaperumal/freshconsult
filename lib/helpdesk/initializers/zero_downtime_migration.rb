module ZeroDowntimeMigration
	def zero_downtime_migration_methods args
		methods = args[:methods]
		class_eval do
			methods.keys.each do |method_name|
				if method_name == :remove_columns
					class_attribute :remove_columns_attributes
					self.remove_columns_attributes = methods[:remove_columns]
					def self.columns
						@cols ||= super.reject {|c| remove_columns_attributes.include?(c.name) }
					end
				end
			end
		end
	end
end
ActiveRecord::Base.extend ZeroDowntimeMigration