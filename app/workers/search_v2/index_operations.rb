class SearchV2::IndexOperations
  
  include Sidekiq::Worker

  sidekiq_options :queue => :es_v2_shard1, :retry => 2, :backtrace => true, :failures => :exhausted

  # Worker class to add document insert/updates to ES
  #
  class DocumentAdd < SearchV2::IndexOperations
    def perform(args)
      args.symbolize_keys!

      entity  = args[:klass_name].constantize.find_by_account_id_and_id(args[:account_id], [:document_id])

      Search::V2::IndexRequestHandler.new(
                                            args[:type],
                                            args[:account_id],
                                            args[:document_id]
                                          ).send_to_es(
                                                        args[:version],
                                                        entity.to_esv2_json
                                                      ) if entity
    end
  end

  # Worker class to remove document from ES
  #
  class DocumentRemove < SearchV2::IndexOperations
    def perform(args)
      args.symbolize_keys!
      Search::V2::IndexRequestHandler.new(
                                            args[:type], 
                                            args[:account_id], 
                                            args[:document_id]
                                          ).remove_from_es
    end
  end
end