module Freshfone::Search
	def self.search_user_with_number(phone_number)
		return if !ES_ENABLED || phone_number.blank?
		search_user_using_es(phone_number)
	end

	def self.search_user_using_es(phone_number)
		# Search::EsIndexDefinition.es_cluster(Account.current.id)
		if Account.current.id == 1010000169
      Search::EsIndexDefinition.es_cluster(Account.current.id, true)
    else
      Search::EsIndexDefinition.es_cluster(Account.current.id)
    end
		index_name = Search::EsIndexDefinition.searchable_aliases([User], Account.current.id)
		Tire.search(index_name, { :load => { :include => :avatar } }) do |search|
			search.query { |q| q.string(phone_number, :fields => ['phone', 'mobile']) }
		end.results.first
	end
end