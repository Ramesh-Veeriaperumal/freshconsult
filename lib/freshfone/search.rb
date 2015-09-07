module Freshfone::Search
	def search_user_with_number(phone_number)
		return if !ES_ENABLED || phone_number.blank?
		search_user_using_es(phone_number, ['phone', 'mobile']).first
	end

	def search_requester(requester_name)
		return if !ES_ENABLED || requester_name.blank?
		search_user_using_es(requester_name, ['name', 'email', 'phone', 'mobile'])
	end
	
	def search_contact(contact, size = 10)
		return if !ES_ENABLED || contact.blank?
		search_user_using_es(contact, ['name', 'phone', 'mobile', custom_field_data_columns].flatten, size)
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

	def search_user_using_es(search_string, fields, size = 10)
		Search::EsIndexDefinition.es_cluster(Account.current.id)
		index_name = Search::EsIndexDefinition.searchable_aliases([User], Account.current.id)
		Tire.search(index_name, { :load => { User => { :include => [:avatar] } }, :size => size }) do |search|
			search.query do |q|
				q.filtered do |f|
					f.query { match fields, search_string, :type => :phrase_prefix }
					f.filter :bool, :should => phone_number_fields
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

end