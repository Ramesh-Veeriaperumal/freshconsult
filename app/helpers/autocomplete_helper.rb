# encoding: utf-8
module AutocompleteHelper

	#View method
	def render_customer_autocomplete
		render(:partial => "helpdesk/shared/autocomplete_select", :locals => { 
																																						:url => customer_helpdesk_autocomplete_path, 
																																						:selected_values => @selected_customers, 
																																						:container => "customers" 
																																					})
	end

	#For customers repopulation
	def selected_customers customer_ids
		Account.current.customers_from_cache.select { |c| customer_ids.include?(c.id.to_s) }
	end
end