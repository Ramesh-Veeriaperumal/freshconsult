class Search::RemoveFromIndex
  include Tire::Model::Search if ES_ENABLED

  class Document < Search::RemoveFromIndex
    extend Resque::AroundPerform
    @queue = 'es_index_queue'

    def self.perform(args)
      args.symbolize_keys!
      klass = args[:klass_name].constantize
      index_alias = Search::EsIndexDefinition.searchable_aliases(Array(klass), args[:account_id]).to_s
      Tire.index(index_alias).remove(klass.document_type, args[:id])
    end
  end

  class AllDocuments < Search::RemoveFromIndex
    @queue = 'es_index_queue'

    def self.perform(args)
      args.symbolize_keys!
      query = Tire.search do |search|
        search.query { |q| q.term :account_id, args[:account_id] }
      end
      klasses = [ User, Helpdesk::Ticket, Solution::Article, Topic, Customer, Helpdesk::Note ]
      search_aliases = Search::EsIndexDefinition.searchable_aliases(klasses, args[:account_id])
      search_aliases.each do |index_alias|
        index = Tire.index(index_alias)
        Tire::Configuration.client.delete "#{index.url}/_query?source=#{Tire::Utils.escape(query.to_hash[:query].to_json)}"
      end
      Search::EsIndexDefinition.remove_aliases(args[:account_id])
    end
  end
end