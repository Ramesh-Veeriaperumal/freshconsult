class SearchSidekiq::RemoveFromIndex < SearchSidekiq::BaseWorker

  class Document < SearchSidekiq::RemoveFromIndex
    def perform(args)
      return unless Account.current.esv1_enabled?

      args.symbolize_keys!
      klass = args[:klass_name].constantize
      index_alias = Search::EsIndexDefinition.searchable_aliases(Array(klass), Account.current.id).to_s
      remove_from_es(index_alias, args[:klass_name], args[:id])
    end
  end

  class ForumTopics < SearchSidekiq::RemoveFromIndex
    def perform(args)
      return unless Account.current.esv1_enabled?

      args.symbolize_keys!
      query = Tire.search do |search|
                search.query do |query|
                  query.filtered do |f|
                    f.filter :term,  { :account_id => Account.current.id } 
                    f.filter :terms,  { :_id => args[:deleted_topics] } 
                  end
                end
              end
      index_alias = Search::EsIndexDefinition.searchable_aliases([Topic], Account.current.id).to_s
      remove_by_query(index_alias, query)
    end
  end

  class AllDocuments < SearchSidekiq::RemoveFromIndex
    def perform
      return unless Account.current.esv1_enabled?

      query = Tire.search do |search|
        search.query { |q| q.term :account_id, Account.current.id }
      end
      klasses = [ User, Helpdesk::Ticket, Solution::Article, Topic, Customer, Helpdesk::Note, Helpdesk::Tag, Freshfone::Caller, Admin::CannedResponses::Response, ScenarioAutomation ]
      search_aliases = Search::EsIndexDefinition.searchable_aliases(klasses, Account.current.id)
      search_aliases.each do |index_alias|
        remove_by_query(index_alias, query)
      end
      Search::EsIndexDefinition.remove_aliases(Account.current.id) if index_present?(search_aliases.first, Account.current.id)
    end
  end

end