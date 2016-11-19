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
    @request_object = Search::V2::IndexRequestHandler.new(
                                          @type, 
                                          @account_id, 
                                          @doc_id
                                        )
    @request_object.remove_from_es
    
    # Multiplexing for pinnacle sports currently
    #=> Entity will not be available to find out the locale
    # if entity.is_a?(Solution::Article) && Account.current.es_multilang_soln?
    #   locale = entity.solution_folder_meta.solution_category_meta.portals.last.try(:language)
    #   @request_object.remove_from_multilang_es(locale)
    # end
  end
end