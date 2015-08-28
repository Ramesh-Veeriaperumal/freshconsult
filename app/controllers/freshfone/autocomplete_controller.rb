class Freshfone::AutocompleteController < ApplicationController
	include Freshfone::Search
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

	def customer_contact
		search_string = params[:q].gsub(/[-()+]/, '')
		result = search_contact_in_user(search_string)
		respond_to do |format|
			format.html { render :partial => 'layouts/shared/freshfone/freshfone_search_results' , :object => result[:results] }
		end
	end

	private

	def format_requester_results (requesters)
		return {:results => [] } if requesters.blank?
		requesters.results.compact!
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

	def format_contact_results (contacts)
		return {:results => [] } if contacts.blank?
		contacts.results.compact!
		{ :results => contacts.results.map do |contact|
				{ 
					:user => contact,
					:id => contact.id,
				  :value => contact.name,
				  :phone => contact.phone,
				  :mobile => contact.mobile,
				  :company => contact.customer_id ? contact.company.name : nil,
				  :custom_field => contact_custom_field(contact), 
				  :custom_name => custom_field_column_names
				} 
			end
		}
	end

	def contact_custom_field (contact) 
		custom_field_data_columns.map do |field|
		  contact.flexifield[field]
		end
	end

	def format_customer_numbers (customer_numbers)
		return {:results => [] } if customer_numbers.blank?
		customer_numbers.results.compact!
		{ :results =>	customer_numbers.results.map do |c_number| 
				{
					:id => c_number.id,
					:value => c_number.number
				}	
			end
		}
	end

	def search_in_caller(search_string)
		customer_numbers = search_customer_number("*#{search_string}*")
		format_customer_numbers(customer_numbers)
	end

	def search_contact_in_user(search_string)
		contacts = search_contact("*#{search_string}*")
		format_contact_results(contacts)
	end

	def search_in_user(search_string)
		requesters = search_requester("*#{search_string}*")
		format_requester_results(requesters)
	end
end
