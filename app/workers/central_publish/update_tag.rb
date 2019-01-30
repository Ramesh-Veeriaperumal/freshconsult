module CentralPublish
  class UpdateTag < BaseWorker
    sidekiq_options :queue => :update_taggables_queue, :retry => 5, :backtrace => true, :failures => :exhausted

    def perform(args)

      args = args.deep_symbolize_keys
      added_tags = {}
      removed_tags = {}
      added_tags = args[:added_tags] if args.key?(:added_tags)
      removed_tags = args[:removed_tags] if args.key?(:removed_tags)

      added_tags.each do |tag_name|
        tag = Account.current.tags.where(:name => tag_name).first
        uses_count = [tag.uses_count-1, tag.uses_count]
        tag.model_changes = { tag_uses_count: uses_count }
        tag.manual_publish_to_central(nil, :update, {}, false) if tag
      end

      removed_tags.each do |tag_name|
        tag = Account.current.tags.where(:name => tag_name).first
        if(tag.uses_count < 0)
          uses_count = [tag.uses_count+2,tag.uses_count]
        else
          uses_count = [tag.uses_count+1, tag.uses_count]
        end
        tag.model_changes = { tag_uses_count: uses_count }
        tag.manual_publish_to_central(nil, :update, {}, false) if tag
      end
    end
  end
end