class Search::RemoveFromIndex
  include Tire::Model::Search if ES_ENABLED

  class Document < Search::RemoveFromIndex
    extend Resque::AroundPerform
    @queue = 'es_index_queue'

    def self.perform(args)
      args.symbolize_keys!
      klass = args[:klass_name].constantize
      index_alias = Search::EsIndexDefinition.searchable_aliases(Array(klass), args[:account_id]).to_s
      Search::EsIndexDefinition.es_cluster(args[:account_id])
      Tire.index(index_alias).remove(klass.document_type, args[:id]) if Tire.index(index_alias).exists?
    end
  end

  class ForumTopics < Search::RemoveFromIndex
    extend Resque::AroundPerform
    @queue = 'es_index_queue'

    def self.perform(args)
      args.symbolize_keys!
      query = Tire.search do |search|
                search.query do |query|
                  query.filtered do |f|
                    f.filter :term,  { :account_id => args[:account_id] } 
                    f.filter :terms,  { :_id => args[:deleted_topics] } 
                  end
                end
              end
      index_alias = Search::EsIndexDefinition.searchable_aliases([Topic], args[:account_id]).to_s
      Search::EsIndexDefinition.es_cluster(args[:account_id])
      index = Tire.index(index_alias)
      Tire::Configuration.client.delete "#{index.url}/_query?source=#{Tire::Utils.escape(query.to_hash[:query].to_json)}"
    end
  end

  class AllDocuments < Search::RemoveFromIndex
    @queue = 'es_index_queue'

    def self.perform(args)
      args.symbolize_keys!
      query = Tire.search do |search|
        search.query { |q| q.term :account_id, args[:account_id] }
      end
      klasses = [ User, Helpdesk::Ticket, Solution::Article, Topic, Customer, Helpdesk::Note, Helpdesk::Tag, Freshfone::Caller, Admin::CannedResponses::Response ]
      search_aliases = Search::EsIndexDefinition.searchable_aliases(klasses, args[:account_id])
      Search::EsIndexDefinition.es_cluster(args[:account_id])
      search_aliases.each do |index_alias|
        index = Tire.index(index_alias)
        Tire::Configuration.client.delete "#{index.url}/_query?source=#{Tire::Utils.escape(query.to_hash[:query].to_json)}" if Tire.index(index_alias).exists?
      end
      Search::EsIndexDefinition.remove_aliases(args[:account_id]) if Tire.index(search_aliases.first).exists?
    end
  end
end