class CountES::IndexOperations
  
  include Sidekiq::Worker

  sidekiq_options :queue => :count_es_queue, :retry => 2, :backtrace => true, :failures => :exhausted
  
  class UpdateTaggables < CountES::IndexOperations
    def perform(args)
      args.symbolize_keys!
      tag = Account.current.tags.find(args[:tag_id])
      tag.tag_uses.preload(:taggable).find_in_batches do |taguses|
        taguses.map(&:taggable).map(&:count_es_manual_publish)
      end if tag and Account.current.try(:features?, :countv2_writes)
    end
  end

  class EnableCountES < CountES::IndexOperations
   def perform(args)
      Search::Dashboard::Count.new.create_alias

      Account.current.tickets.visible.find_in_batches(:batch_size => 300) do |tickets|
        tickets.map(&:count_es_manual_publish)
      end
    end
  end

  class DisableCountES < CountES::IndexOperations
    def perform(args)
      args.symbolize_keys!
      Search::Dashboard::Count.new({},args[:account_id], {:shard_name => args[:shard_name]}).remove_alias
    end
  end

end