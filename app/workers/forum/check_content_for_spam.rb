class Forum::CheckContentForSpam < BaseWorker

  include Redis::RedisKeys
  include Redis::OthersRedis
  include Redis::PortalRedis
  include Forum::CheckSpamContent

  sidekiq_options :queue => :forum_content_spam_checker, :retry => 1, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    @account = Account.current
    Rails.logger.info "Running Forum::CheckContentForSpam for Account : #{Account.current.id}, topic_id : #{args[:topic_id].to_s} post_id: #{args[:post_id].to_s} "
    if args[:post_id].present?
      check_post_description_for_spam args[:post_id], args[:topic_id] 
    else
      check_topic_title_for_spam(args[:topic_id])
    end
  end
  
end
