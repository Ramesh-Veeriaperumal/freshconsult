# Deregister tenant details in ES on account destroy
#
class Search::V2::Operations::DisableSearch

  def initialize(args)
    args.symbolize_keys!

    @account_id = args[:document_id]
  end
  
  def perform
    ES_V2_SUPPORTED_TYPES.keys.each do |es_type|
      Search::V2::IndexRequestHandler.new(es_type, @account_id, nil).remove_by_query({ account_id: @account_id })
    end
    
    Search::V2::Tenant.new(@account_id).rollback
  end
end