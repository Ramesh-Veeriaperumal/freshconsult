module CentralPublish
  class UpdateTaggables < BaseWorker
    include BulkOperationsHelper

    sidekiq_options :queue => :update_taggables_queue, :retry => 2, :backtrace => true, :failures => :exhausted

    def perform(args)
      args = args.deep_symbolize_keys
      tag = Account.current.tags.find_by_id(args[:tag_id])
      # TODO: Publish other models that are taggable - user, archive_ticket and articles
      # after central is enabled for them.
      tag.tickets.find_in_batches_with_rate_limit(rate_limit: rate_limit_options(args)) do |tickets|
        tickets.each do |t|
          if args[:changes] && args[:changes][:name]
            tag_names = args[:changes][:name]
            t.model_changes = { tags: { added: [tag_names[1]], removed: [tag_names[0]] } }
            t.manual_publish_to_central(nil, :update, {}, true)
          end
        end
      end if tag
    end
  end
end