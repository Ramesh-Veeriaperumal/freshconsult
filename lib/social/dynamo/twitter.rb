module Social::Dynamo::Twitter
  include Social::Util
  include Social::Dynamo::Feed
  include Social::Dynamo::Interaction
  include Social::Constants
  include Gnip::Constants

  def update_tweet(args, attributes, gnip_twt_feed, tweet_obj)
    id = args[:stream_id]
    args[:stream_id] = id.starts_with?(TAG_PREFIX) ? id.gsub(TAG_PREFIX, "") : id
    posted_time = Time.parse(gnip_twt_feed.posted_time)
    attributes.merge!(:posted_time => "#{(posted_time.to_f * 1000).to_i}")
    can_insert_feed = true
    if gnip_twt_feed.in_reply_to and !has_parent_feed?(posted_time, args, attributes, gnip_twt_feed)
      can_insert_feed = false
    end
    update_tweet_in_dynamo(posted_time, args, attributes, gnip_twt_feed) if can_insert_feed or !requeue(tweet_obj)
  end

  def update_tweet_in_dynamo(posted_time, args, attributes, gnip_twt_feed)
    dynamo_hash_key = "#{args[:account_id]}_#{args[:stream_id]}"
    parent_feed_id_hash = insert_feed(posted_time, args, attributes, gnip_twt_feed)
    params = {
      :in_reply_to_user_id => gnip_twt_feed.twitter_user_id,
      :id                  => gnip_twt_feed.feed_id
    }
    insert_user_interactions(posted_time, dynamo_hash_key, parent_feed_id_hash, params)
  end

  def update_dm(stream_id, dm_params)
    dm_hash = {
      :body => "#{dm_params[:body]}",
      :id => "#{dm_params[:id]}"
    }
    user_id = dm_params[:user_id]
    posted_time = Time.parse(dm_params[:posted_at])
    insert_user_dm_interactions(posted_time, stream_id, user_id, dm_hash)
  end

  def update_live_feed(posted_time, args, dynamo_params, feed_obj )
    dynamo_hash_key = "#{args[:account_id]}_#{args[:stream_id]}"
    attributes = { :posted_time => "#{(posted_time.to_f * 1000).to_i}" }
    attributes.merge!(:replied_by => "@#{feed_obj.user[:screen_name]}") if args[:tweeted] and !args[:tweeted_with_mention]
    dynamo_params.merge!(:live_feed => true)
    parent_feed_id_hash = insert_feed(posted_time, args, attributes, feed_obj, dynamo_params)
    params = {
      :in_reply_to_user_id => feed_obj.user[:id],
      :id                  => feed_obj.feed_id
    }
    insert_user_interactions(posted_time, dynamo_hash_key, parent_feed_id_hash, params)
  end

  def update_brand_streams_reply(stream_id, reply_params, note)
    posted_time = Time.parse(reply_params[:posted_at])
    reply_params.merge!(:source => SOURCE[:twitter])

    parent_feed_id_hash = update_feed_reply(stream_id, posted_time, reply_params, note)
    insert_user_interactions(posted_time, stream_id, parent_feed_id_hash, reply_params)
  end

  def update_custom_streams_reply(reply_params, stream_id, note)
    posted_time = Time.parse(reply_params[:posted_at])
    reply_params.merge!(:source => SOURCE[:twitter])
    parent_feed_id_hash = {}
    parent_data = {
      :feed_id         => reply_params[:id],
      :in_conversation => 0
    }

    table = "feeds"
    times = [posted_time, posted_time + 7.days]
    times.each do |time|
      table_name = Social::DynamoHelper.select_table(table, time)
      schema = TABLES[table][:schema]
      parent_feed_id_hash.merge!("#{time}" => reply_params[:in_reply_to_id] )
      insert_agent_reply(stream_id, reply_params, parent_data, note, table_name)
    end
    insert_user_interactions(posted_time, stream_id, parent_feed_id_hash, reply_params)
  end

  def update_fd_link(stream_id, feed_id, item, user)
    fd_link = helpdesk_ticket_link(item)
    fd_user = user.id
    unless fd_link.nil? && fd_user.nil?
      fd_attributes = {
        :fd_link => fd_link,
        :fd_user => fd_user
      }
      table = "feeds"
      item_hash = feeds_hash(stream_id, feed_id, "", 0, 0, fd_attributes, SOURCE[:twitter])
      times = [Time.now, Time.now + 7.days]
      times.each do |time|
        table_name = Social::DynamoHelper.select_table(table, time)
        Social::DynamoHelper.update(table_name, item_hash, TABLES[table][:schema])
      end
    end
  end
  
  def update_favorite_in_dynamo(stream_id, feed_id, favorite)
    table = "feeds"
    item_hash = feeds_hash(stream_id, feed_id, "", 0, 0, "", SOURCE[:twitter])
    item_hash.merge!(
      "favorite" => { 
        :n => "#{favorite}"
      })
    times = [Time.now, Time.now + 7.days]
    times.each do |time|
      table_name = Social::DynamoHelper.select_table(table, time)
      Social::DynamoHelper.update(table_name, item_hash, TABLES[table][:schema], ["favorite"])
    end
  end

  def delete_fd_link(stream_id, feed_id)
    table = "feeds"
    item_hash = feeds_hash(stream_id, feed_id, "", 0, 0, "", SOURCE[:twitter])
    item_hash.merge!("fd_link" => {})
    times = [Time.now, Time.now + 7.days]
    times.each do |time|
      table_name = Social::DynamoHelper.select_table(table, time)
      Social::DynamoHelper.update(table_name, item_hash, TABLES[table][:schema], [], ["fd_link"])
    end
  end

end
