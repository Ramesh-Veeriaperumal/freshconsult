class Search::RemoveFromIndex
  extend Resque::AroundPerform
  include Tire::Model::Search

  class Document < Search::RemoveFromIndex
    @queue = 'es_index_queue'

    def self.perform(args)
      args.symbolize_keys!
      @item_document_type = args[:klass_name].constantize.document_type
      Tire.index(Account.current.search_index_name).remove(@item_document_type, args[:id])
    end
  end

  class AllDocuments < Search::RemoveFromIndex
    @queue = 'es_index_queue'

    def self.perform(args)
      args.symbolize_keys!
      query = Tire.search do |search|
        search.query { |q| q.term :account_id, args[:account_id] }
      end
      index = Tire.index(Account.current.search_index_name)
      Tire::Configuration.client.delete "#{index.url}/_query?source=#{Tire::Utils.escape(query.to_hash[:query].to_json)}"
    end
  end
end