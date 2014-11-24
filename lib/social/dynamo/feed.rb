module Social::Dynamo::Feed

  include Social::Constants
  include ::Gnip::Constants

  TABLE = "feeds"
  SCHEMA = TABLES[TABLE][:schema]
  
  
  def has_parent_feed?(posted_time, args, attributes, feed_obj)
    table_name = Social::DynamoHelper.select_table(TABLE, posted_time)
    range_key = SCHEMA[:range][:attribute_name]
    hash = "#{args[:account_id]}_#{args[:stream_id]}"
    attributes_to_get = [range_key, "parent_feed_id", "in_conversation", "source"]
    parent = Social::DynamoHelper.get_item(table_name, hash, feed_obj.in_reply_to, SCHEMA, attributes_to_get)
    parent[:item] ? true : false
  end

  def insert_feed(posted_time, args, attributes, feed_obj, options = {})
    source = feed_obj.source
    parent_feed_id_hash = {}

    times = [posted_time, posted_time + 7.days]
    times.each do |time|
      table_name = Social::DynamoHelper.select_table(TABLE, time)
      key = "#{args[:account_id]}_#{args[:stream_id]}"
      range = feed_obj.feed_id

      if Social::DynamoHelper.table_validity(TABLE, table_name, Time.now)
        parent_feed_id, in_conversation = fetch_parent_data(table_name, key, range, feed_obj.in_reply_to, feed_obj.feed_id)
        parent_feed_id_hash.merge!("#{time}" => "#{parent_feed_id}")

        attributes.merge!(:parent_feed_id => parent_feed_id)
        if options[:live_feed]
          attributes.merge!(:fd_link => options[:ticket_id]) if options[:ticket_id]
          feed_data = twitter_tweet_hash(options, posted_time)
        else
          feed_data = return_specific_keys(feed_obj.feed_hash, DYNAMO_KEYS[source][TABLE])
        end
        item_hash = feeds_hash(key, range, feed_data, 0, in_conversation, attributes, source)

        # Passing the "false" argument to avoid the updating the DynaoDb during the race
        # condition that happens when reply to a tweet from portal is inserted into dynamo and the same tweet
        # comes as a part of the gnip stream(cos of the rule value from:screenname)
        Social::DynamoHelper.insert(table_name, item_hash, SCHEMA, false)
      end
    end
    parent_feed_id_hash
  end

  def update_feed_reply(stream_id, posted_time, reply_params, note)
    times = [posted_time, posted_time + 7.days]
    parent_feed_id_hash = parent_data =  {}
    in_reply_to = reply_params[:in_reply_to_id]
    times.each do |time|
      table_name = Social::DynamoHelper.select_table(TABLE, time)
      item_hash  = feeds_hash(stream_id, in_reply_to, "", 1, 1, "", reply_params[:source])
      response   = Social::DynamoHelper.update(table_name, item_hash, SCHEMA)

      if response[:attributes]["parent_feed_id"]
        parent_feed_id = response[:attributes]["parent_feed_id"][:ss].first
        parent_feed_id_hash.merge!("#{time}" => "#{parent_feed_id}" )
        parent_data = {
          :feed_id => parent_feed_id,
          :in_conversation => 1
        }
        insert_agent_reply(stream_id, reply_params, parent_data, note, table_name)
      end
    end
    parent_feed_id_hash
  end

  def insert_agent_reply(stream_id, reply_params, parent_data, note, table_name)
    posted_time = Time.parse(reply_params[:posted_at])
    reply_hash  = construct_agent_reply_hash(reply_params, posted_time, parent_data[:feed_id], note)
    hash        = stream_id
    range       = reply_params[:id]

    item_hash = feeds_hash(hash, range, reply_hash[:data], 0, parent_data[:in_conversation],
                                reply_hash[:fd_attributes], reply_params[:source])
    Social::DynamoHelper.insert(table_name, item_hash, SCHEMA)
  end

  def feeds_hash(hash, range, data, reply, conversation, attributes, source)
    item = {
      "stream_id" => {
        :s => "#{hash}"
      },
      "feed_id" => {
        :s => "#{range}"
      },
      "is_replied" => {
        :n => "#{reply}"
      },
      "in_conversation" => {
        :n => "#{conversation}"
      },
      "source" => {
        :s => source
      }
    }

    if data.is_a?(Hash)
      item.merge!("data" => {
                    :ss => [data.to_json]
      })
    end

    if attributes.is_a?(Hash)
      attributes.delete_if { |key, value| value.blank? }
      attributes.each do |key, val|
        value = val.is_a?(Array) ? val : [val.to_s]
        item.merge!(key.to_s =>{ :ss => value }) unless value.blank?
      end
    end

    return item
  end


  private

  def fetch_parent_data(table_name, hash, range, in_reply_to, feed_id)
    parent_feed_id  = "#{feed_id}"
    in_conversation = 0
    if in_reply_to
      range_key = SCHEMA[:range][:attribute_name]
      attributes_to_get = [range_key, "parent_feed_id", "in_conversation", "source"]

      parent = Social::DynamoHelper.get_item(table_name, hash, in_reply_to, SCHEMA, attributes_to_get)
      if parent[:item] and parent[:item]["parent_feed_id"]
        parent_feed_id  = parent[:item]["parent_feed_id"][:ss]
        in_conversation = 1
        parent_conversation = parent[:item]["in_conversation"][:n].to_i
        source = parent[:item]["source"][:s]
        if parent_conversation == 0
          item_hash = feeds_hash(hash, in_reply_to, "", 0, 1, "", source)
          Social::DynamoHelper.update(table_name, item_hash, SCHEMA)
        end
      end
    end
    [parent_feed_id, in_conversation]
  end

  def return_specific_keys(hash, keys)
    new_hash = {}
    keys.each do |key|
      if key.class.name == "String"
        new_hash[key] = hash[key.to_sym]
      elsif key.class.name == "Hash"
        current_key = key.keys.first
        if !hash[current_key.to_sym].nil?
          new_hash[current_key] = return_specific_keys(hash[current_key.to_sym].symbolize_keys!, key[current_key])
        end
      end
    end
    return new_hash
  end

  def construct_agent_reply_hash(reply_params, posted_time, parent_feed_id, note)
    dynamo_posted_time = Time.parse(reply_params[:posted_at]).utc
    data = twitter_tweet_hash(reply_params, dynamo_posted_time, true)
    fd_attributes = {
      :posted_time    => "#{(posted_time.to_f * 1000).to_i}",
      :replied_by     => reply_params[:agent_name] ,
      :fd_link        => helpdesk_ticket_link(note),
      :parent_feed_id => parent_feed_id
    }
    return { :data => data, :fd_attributes => fd_attributes }
  end

  def twitter_tweet_hash(reply_params, dynamo_posted_time, reply = false)
    data = {
      "body"  => reply_params[:body],
      "actor" => {
        "displayName"       => reply_params[:user][:name],
        "preferredUsername" => reply_params[:user][:screen_name] ,
        "image"             => reply_params[:user][:image],
        "id"                => (reply ? reply_params[:in_reply_to_user_id] : reply_params[:user][:id])
      },
      "id"         => reply_params[:id],
      "postedTime" => dynamo_posted_time.strftime("%FT%T.000Z"),
      "inReplyTo"  => {
        "link" => reply_params[:in_reply_to_id]
      },
      "twitter_entities" => {
        "user_mentions" => reply_params[:user_mentions]
      }
    }
  end
end
