class Community::ForumPostSpamMarker < BaseWorker

  include SpamAttachmentMethods
  include SpamPostMethods

  sidekiq_options :queue => :forum_post_spam_marker, :retry => 0, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    Account.current.topics.where(id: args[:topic_ids]).preload(:posts).
      find_in_batches(batch_size: 500) do |topics|
      topics.each do |topic|
        begin
          if create_dynamo_post(topic.posts.first)
            topic.destroy 
          end
        rescue => e
          Rails.logger.error "Exception while marking forum post as spam 
          for topic id: #{topic.id},\n#{e.message}\n#{e.backtrace.join("\n\t")}"
          NewRelic::Agent.notice_error(e, 
            description: "Exception while marking forum post as spam 
          for topic id: #{topic.id}")
        end
      end
    end
  rescue => e
    Rails.logger.error "Exception while performing bulk spam of topics,\n#{e.message}
      \n#{e.backtrace.join("\n\t")}"
    NewRelic::Agent.notice_error(e, 
      description: 'Exception while performing bulk spam of topics')
  end
end