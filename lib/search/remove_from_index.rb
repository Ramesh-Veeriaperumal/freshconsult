class Search::RemoveFromIndex
  extend Resque::AroundPerform
  include Tire::Model::Search
  @queue = "es_index_queue"

  def self.perform(args)
    args.symbolize_keys!
    @item_document_type = args[:klass_name].constantize.document_type
    Tire.index(Account.current.search_index_name).remove(@item_document_type, args[:id])
  end
end