class SearchSidekiq::Notes < SearchSidekiq::BaseWorker

  class RestoreNotesIndex < SearchSidekiq::Notes
    def perform(args)
      tickets = Account.current.tickets.find(args["ticket_id"])
      tickets.notes.exclude_source('meta').each do |note|
        Search::EsIndexDefinition.es_cluster(note.account_id)
        note.class.index_name note.search_alias_name
        note.tire.update_index_es
      end
    end
  end

  class DeleteNotesIndex < SearchSidekiq::Notes
    def perform(args)
      account = Account.current
      query = Tire.search do |search|
        search.query do |query|
          query.filtered do |f|
            f.filter :term,  { :account_id => account.id } 
            f.filter :term,  { :notable_id => args["ticket_id"] } 
          end
        end
      end
      index_alias = Search::EsIndexDefinition.searchable_aliases([Helpdesk::Note], account.id).to_s
      Search::EsIndexDefinition.es_cluster(account.id)
      index = Tire.index(index_alias)
      Tire::Configuration.client.delete "#{index.url}/_query?source=#{Tire::Utils.escape(query.to_hash[:query].to_json)}"
    end
  end

end