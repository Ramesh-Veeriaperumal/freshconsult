class SearchSidekiq::Notes < SearchSidekiq::BaseWorker

  class RestoreNotesIndex < SearchSidekiq::Notes
    def perform(args)
      tickets = Account.current.tickets.find(args["ticket_id"])
      tickets.notes.exclude_source('meta').each do |note|
        send_to_es(note)
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
      remove_by_query(index_alias, query)
    end
  end

end