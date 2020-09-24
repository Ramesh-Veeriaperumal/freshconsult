class Social::Dynamo::Facebook 
  
  include Social::Util
  include Facebook::Constants
  
  attr_accessor :feeds_helper, :interactions_helper
  
  def initialize
    @feeds_helper        = Social::Dynamo::Feed::Facebook.new
    @interactions_helper = Social::Dynamo::Interaction.new
  end
  
  def has_parent_feed?(posted_time, args, in_reply_to, consistent_read = true)
    feeds_helper.has_parent_feed?(posted_time, args, in_reply_to, consistent_read)
  end
  
  def dynamo_feed(posted_time, args, feed_id, consistent_read = true)
    feeds_helper.dynamo_feed(posted_time, args, feed_id, consistent_read)
  end

  def insert_post_in_dynamo(post)
    time = Time.now.utc
    args, parent_feed_id_hash = insert_feed_in_dynamo(post, time)  
    insert_feed_interactions(post.koala_post, args, parent_feed_id_hash, time)
  end

  def insert_comment_in_dynamo(comment)
    time          = Time.now.utc
    koala_comment = comment.koala_comment
    fan_page      = comment.fan_page
    
    args, parent_feed_id_hash = insert_feed_in_dynamo(comment, time)
    insert_feed_interactions(comment.koala_comment, args, parent_feed_id_hash, time)
    
    #Insert interactions for comment
    parent_comment = koala_comment.parent.present? ? koala_comment.parent[:id] : koala_comment.feed_id
    
    dynamo_hash_key = "#{args[:account_id]}_#{args[:stream_id]}"
    if comment.instance_of?(Facebook::Core::ReplyToComment)
      feeds_helper.update_parent_comment_in_dynamo(dynamo_hash_key, parent_comment, time, comment.source) 
    end
    interactions_helper.update_comment_interation_list(koala_comment.created_at, dynamo_hash_key, parent_comment,                          koala_comment.feed_id)
    
  end
  
  def update_likes_in_dynamo(likes)
    likes.each do |like|
      keys           = like.first.split(HASH_KEY_DELIMITER)
      feed_id        = keys.first
      hash_key       = keys.last
      post_likes     = like.last
      feeds_helper.update_likes(hash_key, feed_id, post_likes)
    end
  end
  
  def update_ticket_links_in_dynamo(feed_id, stream_id)
    table = "feeds"
    retention_period = TABLES[table][:retention_period]
    times = [Time.now.utc, Time.now.utc + retention_period]
    times.each do |time|
      table_name = Social::DynamoHelper.select_table(table, time)
      feeds_helper.update_fd_links(table_name, feed_id, "#{Account.current.id}_#{stream_id}")
    end
  end

  def fetch_feeds(feed_id, stream_id)
    dynamo_hash_key = "#{Account.current.id}_#{stream_id}"
    feed_interaction = interactions_helper.get_feed_interaction(dynamo_hash_key, feed_id)
    feeds_responses = []
    if feed_interaction.present?
      feed_ids = feed_interaction['feed_ids']
      feed_ids.each_slice(90) do |ids|
        feeds_responses << feeds_helper.get_feeds_data(batch_get_feed_params(dynamo_hash_key, ids))
      end
    end
    feeds_responses.flatten
  end

  def delete_fd_link(stream_id, feed_id)
    feeds_helper.delete_fd_link(stream_id, feed_id, SOURCE[:facebook])
  end

  private
  
  def insert_feed_in_dynamo(feed, time)
    fan_page            = feed.fan_page
    args                = dynamo_hash_and_range_key(fan_page.default_stream_id)
    user                = feed.account.all_users.find_by_fb_profile_id(feed.koala_feed.requester[:id])
    feed_attributes     = fb_feed_info(feed.fd_item, user, feed)  
    parent_feed_id_hash = feeds_helper.insert_feed(time, args, feed_attributes, feed)
    [args, parent_feed_id_hash]
  end
  
  def insert_feed_interactions(koala_feed, dynamo_key, parent_feed_id_hash, time)
    params = {
      :in_reply_to_user_id => koala_feed.requester_fb_id,
      :id                  => koala_feed.feed_id
    }
    dynamo_hash_key = "#{dynamo_key[:account_id]}_#{dynamo_key[:stream_id]}"
    interactions_helper.insert_user_interactions(time, dynamo_hash_key, parent_feed_id_hash, params)
  end
  
  def batch_get_feed_params(stream_id, feed_ids)
    feeds_table_keys = feed_ids.inject([]) do |arr, feed_id|
      arr << {
        'stream_id' => stream_id,
        'feed_id' => feed_id
      }
      arr
    end
  end

end
