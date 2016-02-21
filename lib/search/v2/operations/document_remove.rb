# Class to remove document from ES
#
class Search::V2::Operations::DocumentRemove

  def initialize(args)
    args.symbolize_keys!

    @type       = args.delete(:type)
    @account_id = args.delete(:account_id)
    @doc_id     = args.delete(:document_id)
    @params     = args
  end

  def perform
    Search::V2::IndexRequestHandler.new(
                                          @type, 
                                          @account_id, 
                                          @doc_id
                                        ).remove_from_es
  end
end