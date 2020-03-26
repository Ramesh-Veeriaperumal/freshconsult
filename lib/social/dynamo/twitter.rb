class Social::Dynamo::Twitter 
  
  include Gnip::Constants
  include Social::Gnip::Util
  
  include Social::Util
  include Social::Constants
  include Social::Twitter::Constants
  
  attr_accessor :feeds_helper, :interactions_helper
  
  def initialize
    @feeds_helper        = Social::Dynamo::Feed::Twitter.new
    @interactions_helper = Social::Dynamo::Interaction.new
  end

  def update_live_feed(posted_time, args, dynamo_params, feed_obj )
    dynamo_hash_key = "#{args[:account_id]}_#{args[:stream_id]}"
    attributes = { :posted_time => "#{(posted_time.to_f * 1000).to_i}" }
    attributes.merge!(:replied_by => "@#{feed_obj.user[:screen_name]}") if args[:tweeted] and !args[:tweeted_with_mention]
    dynamo_params.merge!(:live_feed => true)
    parent_feed_id_hash = feeds_helper.insert_feed(posted_time, args, attributes, feed_obj, dynamo_params)
    params = {
      :in_reply_to_user_id => feed_obj.user[:id],
      :id                  => feed_obj.feed_id
    }
    interactions_helper.insert_user_interactions(posted_time, dynamo_hash_key, parent_feed_id_hash, params)
  end

  def update_brand_streams_reply(stream_id, reply_params, note)
    posted_time = Time.parse(reply_params[:posted_at])
    reply_params.merge!(:source => SOURCE[:twitter])

    parent_feed_id_hash = feeds_helper.update_feed_reply(stream_id, posted_time, reply_params, note)
    interactions_helper.insert_user_interactions(posted_time, stream_id, parent_feed_id_hash, reply_params)
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
    retention_period = TABLES[table][:retention_period]
    times = [posted_time, posted_time + retention_period]
    times.each do |time|
      table_name = Social::DynamoHelper.select_table(table, time)
      schema = TABLES[table][:schema]
      parent_feed_id_hash.merge!("#{time}" => reply_params[:in_reply_to_id] )
      feeds_helper.insert_agent_reply(stream_id, reply_params, parent_data, note, table_name)
    end
    interactions_helper.insert_user_interactions(posted_time, stream_id, parent_feed_id_hash, reply_params)
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
      retention_period = TABLES[table][:retention_period]
      item_hash = feeds_helper.feeds_hash(stream_id, feed_id, "", 0, 0, fd_attributes, SOURCE[:twitter])
      times = [Time.now, Time.now + retention_period]
      times.each do |time|
        table_name = Social::DynamoHelper.select_table(table, time)
        Social::DynamoHelper.update(table_name, item_hash, TABLES[table][:schema])
      end
    end
  end
  
  def update_favorite_in_dynamo(stream_id, feed_id, favorite)
    table = "feeds"
    item_hash = feeds_helper.feeds_hash(stream_id, feed_id, "", 0, 0, "", SOURCE[:twitter])
    item_hash.merge!(
      "favorite" => { 
        :n => "#{favorite}"
      })
    retention_period = TABLES[table][:retention_period]
    times = [Time.now, Time.now + retention_period]
    times.each do |time|
      table_name = Social::DynamoHelper.select_table(table, time)
      Social::DynamoHelper.update(table_name, item_hash, TABLES[table][:schema], ["favorite"])
    end
  end
  
  def delete_fd_link(stream_id, feed_id)
    feeds_helper.delete_fd_link(stream_id, feed_id, SOURCE[:twitter])
  end

  private
  def fetch_parent_data(table_name, hash, feed_obj)
    in_conversation = 0
    in_reply_to     = feed_obj.in_reply_to
    feed_id         = feed_obj.feed_id
    parent_feed_id  = "#{feed_id}"
    
    if in_reply_to
      attributes_to_get = [RANGE_KEY, "parent_feed_id", "in_conversation", "source"]
      parent_attributes = get_parent_data(table_name, hash, in_reply_to, attributes_to_get)
      parent_feed_id    = parent_attributes[:parent_feed_id] if parent_attributes.present?
      if parent_attributes.present? and parent_attributes[:parent_conversation] == 0
        item_hash = feeds_hash(hash, in_reply_to, "", 0, 1, "", parent_attributes[:source])
        Social::DynamoHelper.update(table_name, item_hash, SCHEMA)
      end
    end
    [parent_feed_id, in_conversation, feed_id]
  end

end
