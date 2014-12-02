module Social::Dynamo::Facebook

  include Social::Util
  include Social::Dynamo::Feed
  include Social::Dynamo::Interaction
  

  def update_post_in_dynamo(post, ticket)
    return unless post.account.features?(:social_revamp)
    
    posted_time = post.koala_post.created_at
    
    args = dynamo_hash_and_range_key(post)
    
    feed_attributes = fd_info(ticket, post.koala_post, post.type)

    parent_feed_id_hash = insert_feed(posted_time, args, feed_attributes, post)

    params = {
      :in_reply_to_user_id => post.koala_post.requester_fb_id,
      :id                  => post.feed_id
    }
    dynamo_hash_key = "#{args[:account_id]}_#{args[:stream_id]}"
    insert_user_interactions(posted_time, dynamo_hash_key, parent_feed_id_hash, params)
  end

  def update_comment_in_dynamo(comment, note)
    return unless comment.account.features?(:social_revamp)
    
    posted_time = comment.koala_comment.created_at
    args = dynamo_hash_and_range_key(comment)
    
    feed_attributes = fd_info(note, comment.koala_comment, comment.type)

    parent_feed_id_hash = insert_feed(posted_time, args, feed_attributes, comment)

    params = {
      :in_reply_to_user_id => comment.koala_comment.requester.fb_profile_id,
      :id                  => comment.feed_id
    }
    dynamo_hash_key = "#{args[:account_id]}_#{args[:stream_id]}"
    insert_user_interactions(posted_time, dynamo_hash_key, parent_feed_id_hash, params)
  end

  private
  def dynamo_hash_and_range_key(obj)
    stream_id   = obj.fan_page.default_stream_id  
    {
      :stream_id  => stream_id,
      :account_id => obj.account.id
    }
  end

end
