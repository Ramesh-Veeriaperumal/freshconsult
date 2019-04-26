# Class to destroy tag uses after tag destroy to trigger callbacks to ES
#
class TagUsesCleaner
  include Sidekiq::Worker

  sidekiq_options :queue => :tag_uses_destroy, :retry => 2, :backtrace => true, :failures => :exhausted
  
  def perform(args)
    args.symbolize_keys!
    
    condition = { tag_id: args[:tag_id] }
    condition[:taggable_type] = args[:taggable_type] if args[:taggable_type]
    Account.current.tag_uses.where(condition).find_in_batches(batch_size: 300) do |tag_uses|
      tag_uses.map(&:destroy)
    end
  end
end