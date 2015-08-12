### MULTILINGUAL SOLUTIONS - META READ HACK!!
module Solution::MetaAssociationSwitcher

	extend ActiveSupport::Concern

	def self.included(base)
		base::FEATURE_BASED_METHODS.each do |method|
			define_method(%{#{method.to_s}_with_association}) do
				account = (self.class.name == "Account") ? self : self.account
				if account.launched?(:meta_read) and !self.new_record?
					send(%{#{method.to_s}_through_meta})
				else
					send(%{#{method.to_s}_without_association})
				end
			end

			base.alias_method_chain method, :association
		end

		if ["Solution::Category", "Solution::Folder", "Solution::Article"].include?(base.name)
			meta_class = "#{base.name}Meta".constantize

			(meta_class::COMMON_ATTRIBUTES).each do |attrib|
				define_method(attrib) do 
					read_attribute(attrib)
				end

				define_method("#{attrib}_through_meta") do
					meta_object.send(attrib)
				end

				define_method(%{#{attrib}_with_association}) do
					if Account.current.launched?(:meta_read) && !send("#{attrib}_changed?") 
						send(%{#{attrib}_through_meta})
					else
						send(%{#{attrib}_without_association})
					end
				end

				base.alias_method_chain attrib.to_sym, :association

				# Alias_method_chain can be removed after successfully migrating everyone to meta_read
				# base.delegate attrib.to_sym, :to => meta_class.table_name.to_sym

			end
		end
	end
end