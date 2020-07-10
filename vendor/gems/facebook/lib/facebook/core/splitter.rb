class Facebook::Core::Splitter
  include Admin::Social::FacebookGatewayHelper

  def initialize(feed)
    @intial_feed = feed
    @feed = Facebook::Core::Feed.new(feed)
  end

  def split
    if @feed.entry_changes
      # find the page using the global facebookmapping table check this code
      Rails.logger.info('Facebook::Core::Splitter')
      status, gateway_fb_accounts_count, gateway_fb_accounts = gateway_facebook_page_mapping_details(@feed.page_id)
      account_id = gateway_fb_accounts.first if status == 200 && gateway_fb_accounts_count > 0

      shard = ShardMapping.lookup_with_account_id(account_id)

      if shard
        pod_info = shard.pod_info

        Rails.logger.info "Facebook message received for POD: #{pod_info}."
        # send message to the specific queue
        AwsWrapper::SqsV2.send_message(pod_info + '_' + SQS[:facebook_realtime_queue], @intial_feed)
      end
    end
  end
end
