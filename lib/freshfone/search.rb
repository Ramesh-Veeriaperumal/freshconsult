module Freshfone::Search
	def search_user_with_number(phone_number)
		return if !ES_ENABLED || phone_number.blank?
		get_es_search_results(phone_number, ['phone', 'mobile']).first
	end

	def search_requester(requester_name, search_non_deleted)
		return if !ES_ENABLED || requester_name.blank?
		search_user_using_es(requester_name, ['name', 'email', 'phone', 'mobile'], 10, search_non_deleted)
	end
	
	def search_contact(contact, size = 10, search_non_deleted)
		return if !ES_ENABLED || contact.blank?
		get_es_search_results(contact, ['name', 'phone', 'mobile', custom_field_data_columns].flatten, size, search_non_deleted)
	end

	def custom_field_data_columns
		@fields ||= custom_phone_fields.map(&:column_name)
	end

	def custom_field_column_names
		custom_phone_fields.map(&:label)
	end

	def custom_phone_fields
		@custom_phone_fields ||= 
			current_account.contact_form.contact_fields.select { |fd| 
				fd.field_type == :custom_phone_number }
	end

	def search_user_using_es(search_string, fields, size, search_non_deleted=true)
		Search::EsIndexDefinition.es_cluster(Account.current.id)
		index_name = Search::EsIndexDefinition.searchable_aliases([User], Account.current.id)
		Tire.search(index_name, { :load => { User => { :include => [:avatar] } }, :size => size }) do |search|
			search.query do |q|
				q.filtered do |f|
					f.query { match fields, search_string, :type => :phrase_prefix }
					f.filter :bool, :should => phone_number_fields
					f.filter :term, { :deleted => false } if search_non_deleted
				end
			end
			search.sort { by :name, 'asc' }
		end.results
	end

	def search_customer_number(phone_number)
		return if !ES_ENABLED || phone_number.blank?
		Search::EsIndexDefinition.es_cluster(Account.current.id)
		index_name = Search::EsIndexDefinition.searchable_aliases([Freshfone::Caller], Account.current.id)
		Tire.search(index_name, {load: true}) do |search|
			search.query do |query|
				query.filtered do |f|
					f.query { match ['number'], phone_number, :type => :phrase_prefix }
				end
			end
		end.results
	end

	def phone_number_fields
		number_fileds = [{:exists => {:field => "phone"}},{:exists => { :field => "mobile"}}]
		custom_field_data_columns.each do |number_filed|
			number_fileds.push({:exists => {:field => number_filed}})
		end
		number_fileds
	end

	private
		def get_es_search_results(search_string, fields, size = 10, search_non_deleted=true)
			es_response = search_user_using_es(search_string, fields, size) if search_non_deleted
			return es_response if (es_response.present? && es_response.results.present?)
			search_user_using_es(search_string, fields, size, false)
		end
end