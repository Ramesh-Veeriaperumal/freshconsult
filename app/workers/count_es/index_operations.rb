class CountES::IndexOperations
  
  include MemcacheKeys  
  include Sidekiq::Worker
  include BulkOperationsHelper

  sidekiq_options :queue => :count_es_queue, :retry => 2, :backtrace => true, :failures => :exhausted
  
  class UpdateTaggables < CountES::IndexOperations
    def perform(args)
      args.symbolize_keys!
      tag = Account.current.tags.find_by_id(args[:tag_id])
      tag.tickets.find_in_batches_with_rate_limit(rate_limit: rate_limit_options(args)) do |tickets|
        tickets.map(&:count_es_manual_publish)
      end if tag
    end
  end

  class EnableCountES < CountES::IndexOperations
   def perform(args)
      account = Account.current
      #Search::Dashboard::Count.new.create_alias
      unless account.features?(:countv2_writes)
        account.features.countv2_writes.create
        count = Search::Dashboard::Count.new(nil, Account.current.id, nil)
        count.index_new_account_dashboard_shard
        key = ACCOUNT_DASHBOARD_SHARD_NAME % { :account_id => Account.current.id }
        MemcacheKeys.fetch(key) { ActiveRecord::Base.current_shard_selection.shard.to_s }
        account.tickets.visible.find_in_batches(:batch_size => 300) do |tickets|
          tickets.map(&:count_es_manual_publish)
        end
      end
      account.features.countv2_reads.create
      [:admin_dashboard, :agent_dashboard, :supervisor_dashboard, :dashboard_new_alias].each do |f|
        account.launch(f)
      end
    end
  end

  class DisableCountES < CountES::IndexOperations
    def perform(args)
      return true #Since new signups wont have dashboard, we dont need to perform this job. We ll remove this line once we start enabling es for new signups.
      #args.symbolize_keys!
      #Search::Dashboard::Count.new({},args[:account_id], {:shard_name => args[:shard_name]}).remove_alias
    end
  end

end