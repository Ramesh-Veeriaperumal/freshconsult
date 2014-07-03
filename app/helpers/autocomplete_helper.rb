# encoding: utf-8
module AutocompleteHelper

	MAX_SELECTION_SIZE = 100
	AUTOCOMPLETE_DEFAULTS = 	{ 
								:customers => {
																:url => "/helpdesk/autocomplete/customer",
																:container => "customers",
																:max_limit => MAX_SELECTION_SIZE
								},
								:requesters => {
																	:url => "/helpdesk/autocomplete/requester",
																	:container => "requester",
																	:max_limit => 3
								}
							} 

	def render_autocomplete args={}
		render(:partial => "helpdesk/shared/autocomplete_select", :locals => AUTOCOMPLETE_DEFAULTS[args[:type]].merge(args))
	end

	#For customers repopulation
	def selected_customers customer_ids
		Account.current.customers_from_cache.select { |c| customer_ids.include?(c.id.to_s) } if customer_ids
	end
end