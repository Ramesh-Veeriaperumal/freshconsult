class Freshfone::AutocompleteController < ApplicationController
	def requester_search
		search_string = params[:q].gsub(/^\+/, '')
		requesters = Freshfone::Search.search_requester("*#{search_string}*")
		result = { :results => requesters.results.map do |requester|
														{	:id => requester.id,
															:value => requester.name,
															:email => requester.email,
															:phone => requester.phone,
															:mobile => requester.mobile
														} 
													end
							}
		respond_to do |format|
			format.json { render :json => result.to_json }
		end
	end
end
