module Solution::MetaAssociationSwitcher

	extend ActiveSupport::Concern

	def self.included(base)
		base::FEATURE_BASED_METHODS.each do |method|
			define_method(%{#{method.to_s}_with_association}) do
				if DYNAMIC_SOLUTIONS
					send(%{#{method.to_s}_with_meta})
				else
					send(%{#{method.to_s}_without_association})
				end
			end
		end

		base::FEATURE_BASED_METHODS.each do |method|
			base.alias_method_chain method, :association
		end
	end
end