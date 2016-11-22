# Class to add document insert/updates to ES
#
class Search::V2::Operations::DocumentAdd

  def initialize(args)
    args.symbolize_keys!

    @klass      = args.delete(:klass_name)
    @type       = args.delete(:type)
    @account_id = args.delete(:account_id)
    @doc_id     = args.delete(:document_id)
    @params     = args
  end

  def perform
    entity = @klass.constantize.find_by_account_id_and_id(@account_id, @doc_id)

    if entity
      # All dates to be stored in UTC
      #
      Time.use_zone('UTC') do
        @request_object = Search::V2::IndexRequestHandler.new(
                                              @type,
                                              @account_id,
                                              @doc_id
                                            )
        @request_object.send_to_es(
                                    @params[:version],
                                    @params[:routing_id],
                                    @params[:parent_id],
                                    entity.to_esv2_json
                                  )
        
        # Multiplexing for pinnacle sports currently
        if entity.is_a?(Solution::Article) && Account.current.es_multilang_soln?
          locale = entity.solution_folder_meta.solution_category_meta.portals.last.try(:language)
          @request_object.send_to_multilang_es(
                                                @params[:version],
                                                @params[:routing_id],
                                                @params[:parent_id],
                                                entity.to_esv2_json,
                                                locale
                                              )
        end
      end
    end
  end
end