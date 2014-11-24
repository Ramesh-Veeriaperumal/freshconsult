module Freshfone::Search
	def self.search_user_with_number(phone_number)
		return if !ES_ENABLED || phone_number.blank?
		search_user_using_es(phone_number, ['phone', 'mobile']).first
	end

	def self.search_requester(requester_name)
		return if !ES_ENABLED || requester_name.blank?
		search_user_using_es(requester_name, ['name', 'email', 'phone', 'mobile'])
	end

	def self.search_user_using_es(search_string, fields)
		Search::EsIndexDefinition.es_cluster(Account.current.id)
		index_name = Search::EsIndexDefinition.searchable_aliases([User], Account.current.id)
		Tire.search(index_name, { :load => { User => { :include => [:avatar] } } }) do |search|
			search.query do |query|
				query.filtered do |f|
					f.query { |q| q.string(search_string, :fields => fields) }
					f.filter :term, { :account_id => Account.current.id }
				end
			end
		end.results
	end

	def self.search_customer_number(phone_number)
		return if !ES_ENABLED || phone_number.blank?
		Search::EsIndexDefinition.es_cluster(Account.current.id)
		index_name = Search::EsIndexDefinition.searchable_aliases([Freshfone::Caller], Account.current.id)
		Tire.search(index_name, {load: true}) do |search|
			search.query do |query|
				query.filtered do |f|
					f.query { |q| q.string(phone_number, :fields => ['number']) }
					f.filter :term, { :account_id => Account.current.id }
				end
			end
		end.results

	end
end