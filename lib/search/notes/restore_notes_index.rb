class Search::Notes::RestoreNotesIndex
  extend Resque::AroundPerform
  include Tire::Model::Search if ES_ENABLED
  @queue = "es_index_queue"

  def self.perform(args)
    tickets = Account.current.tickets.find(args[:ticket_id])
    tickets.notes.exclude_source('meta').each do |note|
      Search::EsIndexDefinition.es_cluster(@update_item.account_id)
      note.class.index_name note.search_alias_name
      note.tire.update_index_es
    end
  end
end