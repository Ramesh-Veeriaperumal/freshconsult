class Freshfone::AutocompleteController < ApplicationController
	def requester_search
		search_string = params[:q].gsub(/^\+/, '')
		result = search_in_user(search_string)
		respond_to do |format|
			format.json { render :json => result.to_json }
		end
	end

	def customer_phone_number
		regex_for_numbers = '^[0-9.]*$'
		search_string = params[:q].gsub(/^\+/, '')
		result = search_string.match(regex_for_numbers) ? 
			search_in_caller(search_string) : search_in_user(search_string)
		respond_to do |format|
			format.json { render :json => result.to_json }
		end
	end

	private

	def format_requester_results (requesters)
		{ :results =>	requesters.results.map do |requester|
				{	:id => requester.id,
					:value => requester.name,
					:email => requester.email,
					:phone => requester.phone,
					:mobile => requester.mobile,
					:user_result => true
				} 
			end
		}
	end

	def format_customer_numbers (customer_numbers)
		{ :results =>	customer_numbers.results.map do |c_number| 
				{
					:id => c_number.id,
					:value => c_number.number
				}	
			end
		}
	end

	def search_in_caller(search_string)
		customer_numbers = Freshfone::Search.search_customer_number("*#{search_string}*")
		format_customer_numbers(customer_numbers)
	end

	def search_in_user(search_string)
		requesters = Freshfone::Search.search_requester("*#{search_string}*")
		format_requester_results(requesters)
	end
end
