class Facebook::Core::Splitter

  def initialize(feed)
    @intial_feed = feed
    @feed = Facebook::Core::Feed.new(feed)
  end

  def split
    if @feed.entry_changes
      #find the page using the global facebookmapping table check this code
      mapping = Social::FacebookPageMapping.find_by_facebook_page_id(@feed.page_id)
      account_id = mapping.account_id if mapping

      shard = ShardMapping.lookup_with_account_id(account_id)

      if shard
        pod_info = shard.pod_info

        Rails.logger.info "Facebook message received for POD: #{pod_info}."
        # send message to the specific queue
        AwsWrapper::SqsQueue.instance.send_message(pod_info + '_' + SQS[:facebook_realtime_queue], @intial_feed)
      end
    end
  end
end