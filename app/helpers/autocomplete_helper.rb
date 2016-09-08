# encoding: utf-8
module AutocompleteHelper

	MAX_SELECTION_SIZE = 100
	MAX_CC_LIMIT = 50
	AUTOCOMPLETE_DEFAULTS = 	{ 
								:companies => {
																:url => "/search/autocomplete/companies",
																:container => "customers",
																:max_limit => MAX_SELECTION_SIZE
								},
								:requesters => {
																	:url => "/search/autocomplete/requesters",
																	:container => "requester",
																	:max_limit => 3
								},
								:company_users => {
																	:url => "/search/autocomplete/company_users",
																	:container => "user",
																	:max_limit => 3	
								},
								:cc_emails => {
																	:url => "/search/autocomplete/company_users",
																	:container => "cc_emails",
																	:max_limit => MAX_CC_LIMIT	
								},
								:tags => {
																	:url => "/search/autocomplete/tags",
																	:container => "tags",
																	:max_limit => MAX_SELECTION_SIZE
								}
							} 

	def render_autocomplete args={}
		render(:partial => "helpdesk/shared/autocomplete_select", :locals => AUTOCOMPLETE_DEFAULTS[args[:type]].merge(args))
	end

	#For customers repopulation
	def selected_companies company_ids
		Account.current.companies.where("id in (?)", company_ids) if company_ids
	end
end
