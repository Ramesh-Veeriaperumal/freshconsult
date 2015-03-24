module FeatureCheck

	def self.included(base)
		base.extend(ClassMethods)
	end

	module ClassMethods
		def feature_check(*features)
			before_filter :enabled_features
			include InstanceMethods
			@features = features
		end

		def features_to_check
			@features
		end
	end

	module InstanceMethods
		def enabled_features
			(self.class.features_to_check || []).each do |feature|
				instance_variable_set("@#{feature.to_s}_feature", current_account.features_included?(feature))
			end
    end
	end

end