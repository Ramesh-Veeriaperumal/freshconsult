class Search::Notes::DeleteNotesIndex
  extend Resque::AroundPerform
  include Tire::Model::Search if ES_ENABLED
  @queue = "es_index_queue"

  def self.perform(args)
   account = Account.current
   query = Tire.search do |search|
      search.query do |query|
        query.filtered do |f|
        f.filter :term,  { :account_id => account.id } 
        f.filter :term,  { :notable_id => args[:ticket_id] } 
    end
    end
   end
   index_alias = Search::EsIndexDefinition.searchable_aliases([Helpdesk::Note], Account.current.id).to_s
   index = Tire.index(index_alias)
   Tire::Configuration.client.delete "#{index.url}/_query?source=#{Tire::Utils.escape(query.to_hash[:query].to_json)}"
  end
end