module Freshfone::Search
	def search_user_with_number(phone_number)
		return if phone_number.blank? || !Account.current.esv1_enabled?
		get_es_search_results(phone_number, ['phone', 'mobile']).first
	end
	
	def search_user_v2(phone_number)
		return if phone_number.blank?

		Search::V2::QueryHandler.new({
			account_id:   current_account.id,
			context:      :ff_contact_by_phone,
			exact_match:  Search::Utils.exact_match?(phone_number),
			es_models:    { 'user' => { model: 'User', associations: []}},
			current_page: Search::Utils::DEFAULT_PAGE,
			offset:       0,
			types:        ['user'],
			es_params:    ({ 
				search_term: phone_number,
				account_id: current_account.id,
				request_id: Thread.current[:message_uuid].try(:first), #=> Msg ID is casted as array.
				isdeleted: false,
				phone_fields_str: custom_field_data_columns.join('\",\"'),
				phone_fields_arr: custom_field_data_columns
			})
		}).query_results.first
	end

	def search_requester(requester_name, search_non_deleted, phone_fields_search = true)
		return if requester_name.blank? || !Account.current.esv1_enabled?
		search_user_using_es(requester_name, ['name', 'email', 'phone', 'mobile'], 10, search_non_deleted, phone_fields_search)
	end
	
	def search_contact(contact, size = 10, search_non_deleted)
		return if contact.blank? || !Account.current.esv1_enabled?
		get_es_search_results(contact, ['name', 'phone', 'mobile', custom_field_data_columns].flatten, size, search_non_deleted)
	end

	def custom_field_data_columns
		@fields ||= custom_phone_fields.map(&:column_name)
	end

	def custom_field_column_names
		custom_phone_fields.map(&:label)
	end

	# Using Account.current as current_account not available
	# when accessing as module function
	def custom_phone_fields
		@custom_phone_fields ||= 
			Account.current.contact_form.contact_fields.select { |fd| 
				fd.field_type == :custom_phone_number }
	end

	def search_user_using_es(search_string, fields, size, search_non_deleted=true, phone_fields_search = true)
		Search::EsIndexDefinition.es_cluster(Account.current.id)
		index_name = Search::EsIndexDefinition.searchable_aliases([User], Account.current.id)
		Tire.search(index_name, { :load => { User => { :include => [:avatar] } }, :size => size }) do |search|
			search.query do |q|
				q.filtered do |f|
					f.query { match fields, search_string, :type => :phrase_prefix }
					f.filter :bool, :should => phone_number_fields if phone_fields_search
					f.filter :term, { :deleted => false } if search_non_deleted
				end
			end
			search.sort { by :name, 'asc' }
		end.results
	end

	def search_customer_number(phone_number)
		return if phone_number.blank? || !Account.current.esv1_enabled?
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
	
	module_function :custom_field_data_columns, :custom_field_column_names, :custom_phone_fields, :phone_number_fields

	def search_customer
	  customer = search_customer_with_id if customer_id.present?
	  return customer if customer.present?
	  search_customer_with_number_using_es(called_number)
	end

	#return contact only if it has phone or mobile number present.
	# <> operator will check for both null and empty fields.
	def search_customer_with_id
	  Sharding.run_on_slave do
	    users_scoper.where(id: customer_id).where(
	      "(phone <> '') OR (mobile <> '')").first
	  end
	end

	#If there are no no-deleted contacts with this number, returning the first deleted contact.
	#this method was returning first user based on Id for the number, so changed to have ordering based on name
	def search_customer_with_number_using_es(phone_number)
	  begin
			if Account.current.launched?(:es_v2_reads)
				search_user_v2(phone_number)
			else
				search_user_with_number(phone_number.gsub(/^\+/, ''))
			end
	  rescue Exception => e
	    Rails.logger.error "Error with elasticsearch for Accout::#{current_account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
	    get_customer_with_number(phone_number)
	  end
	end

	def get_customer_with_number(phone_number)
	  Sharding.run_on_slave do
	  	users_scoper.where('phone = ? or mobile = ?', phone_number,
	  		phone_number).order('deleted ASC, name ASC').first
	  end
	end

	private
		def get_es_search_results(search_string, fields, size = 10, search_non_deleted=true)
			es_response = search_user_using_es(search_string, fields, size) if search_non_deleted
			return es_response if (es_response.present? && es_response.results.present?)
			search_user_using_es(search_string, fields, size, false)
		end

		def users_scoper
		  current_account.all_users
		end

		def called_number
		  params[:PhoneNumber] || params[:To]
		end

		def customer_id
		  params[:customer_id] || params[:customerId]
		end
end