class CountES::IndexOperations
  
  include MemcacheKeys  
  include Sidekiq::Worker
  include BulkOperationsHelper

  sidekiq_options :queue => :count_es_queue, :retry => 2, :failures => :exhausted
  
  class UpdateTaggables < CountES::IndexOperations
    def perform(args)
      args.symbolize_keys!
      tag = Account.current.tags.find_by_id(args[:tag_id])
      tag.tickets.find_in_batches_with_rate_limit(rate_limit: rate_limit_options(args)) do |tickets|
        tickets.map(&:count_es_manual_publish)
      end if tag
    end
  end
end