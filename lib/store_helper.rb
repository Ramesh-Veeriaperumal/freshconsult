#                                    	#
#  Datas to be exposed to clientside 	#
# 										#

module StoreHelper
	def get_store_data
		@agents_list ||= current_account.agents_details_from_cache.inject([]) do |res,agent|
			res << {:id => agent.id, :name => agent.name,  :is_account_admin => agent.email == current_account.admin_email}
		end

		@groups_list ||= current_account.groups_from_cache.inject([]) do |res,group|
			res << {:id => group.id, :name => group.name}
		end
		{:current_user => current_user, :agent => @agents_list, :group => @groups_list}.to_json
	end 
end