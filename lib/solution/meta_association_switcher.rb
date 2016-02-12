### MULTILINGUAL SOLUTIONS - META READ HACK!!
module Solution::MetaAssociationSwitcher

	extend ActiveSupport::Concern

	def self.included(base)
		base::FEATURE_BASED_METHODS.each do |method|
			define_method(%{#{method.to_s}_with_association}) do
				# While bootstrapping/account creation, Current Account is not set.
				# This code is to handle those scenarios
				account = Account.current || ((self.class.name == "Account") ? self : self.account)
				if account.launched?(:solutions_meta_read)# and !self.new_record?
					send(%{#{method.to_s}_through_meta})
				else
					send(%{#{method.to_s}_without_association})
				end
			end

			base.alias_method_chain method, :association
		end
	end
end