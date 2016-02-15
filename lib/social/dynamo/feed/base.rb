class Social::Dynamo::Feed::Base
  
  include Social::Util
  include Social::Constants


  TABLE     = TABLE_NAME["feeds"]
  SCHEMA    = TABLES[TABLE][:schema]
  RANGE_KEY = SCHEMA[:range][:attribute_name]
  
  def has_parent_feed?(posted_time, args, in_reply_to, consistent_read = true)
    parent = dynamo_feed(posted_time, args, in_reply_to)
    parent[:item] ? true : false
  end
  
  def dynamo_feed(posted_time, args, feed_id, consistent_read = true)
    table_name = Social::DynamoHelper.select_table(TABLE, posted_time)
    hash = "#{args[:account_id]}_#{args[:stream_id]}"
    attributes_to_get = [RANGE_KEY, "parent_feed_id", "in_conversation", "source", "fd_link"]
    Social::DynamoHelper.get_item(table_name, hash, feed_id, SCHEMA, attributes_to_get, consistent_read)  
  end

  def insert_feed(posted_time, args, attributes, feed_obj, options = {})
    source = feed_obj.source
    parent_feed_id_hash = {}
    
    execute_on_table(posted_time) do |table_name, time|
      key = "#{args[:account_id]}_#{args[:stream_id]}"

      if Social::DynamoHelper.table_validity(TABLE, table_name, Time.now)
        parent_feed_id, in_conversation, range = fetch_parent_data(table_name, key, feed_obj)
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
    
    item.merge!("data" => { :ss => [data.to_json] }) if data.is_a?(Hash)

    if attributes.is_a?(Hash)
      attributes.delete_if { |key, value| value.blank? }
      
      attributes.each do |key, val|
        if NUMERIC_KEYS.include?("#{key}")
          item.merge!(key.to_s =>{ :n => val.to_s })
        else
          value = val.is_a?(Array) ? val : [val.to_s]
          item.merge!(key.to_s =>{ :ss => value }) 
        end
      end  
    end
    
    item
  end
  
  def get_feeds_data(attributes_to_get)
    feeds_table = {
      :name => Social::DynamoHelper.select_table(TABLE, Time.now.utc),
      :keys => attributes_to_get
    }
    feeds_responses = Social::DynamoHelper.batch_get(feeds_table)
    feeds_responses.map{|result| result[:responses]["#{feeds_table[:name]}"] }.flatten
  end
  
  def delete_fd_link(stream_id, feed_id, source)
    table = "feeds"
    item_hash = feeds_hash(stream_id, feed_id, "", 0, 0, "", source)
    item_hash.merge!("fd_link" => {})
    times = [Time.now, Time.now + 7.days]
    times.each do |time|
      table_name = Social::DynamoHelper.select_table(table, time)
      Social::DynamoHelper.update(table_name, item_hash, TABLES[table][:schema], [], ["fd_link"])
    end
  end


  private
  
  def get_parent_data(table_name, hash, in_reply_to, attributes_to_get)
    parent_attributes = {}
    parent = Social::DynamoHelper.get_item(table_name, hash, in_reply_to, SCHEMA, attributes_to_get)
    if parent[:item] and parent[:item]["parent_feed_id"]
      parent_attributes = {
        :in_conversation => 1,
        :parent_feed_id  => parent[:item]["parent_feed_id"][:ss],
        :parent_conversation => parent[:item]["in_conversation"][:n].to_i,
        :source => parent[:item]["source"][:s]
      }
    end
    parent_attributes
  end

  def return_specific_keys(hash, keys)
    new_hash = {}
    keys.each do |key|
      if key.class.name == "String"
        new_hash[key] = hash[key.to_sym] unless hash[key.to_sym].blank?
      elsif key.class.name == "Hash"
        current_key = key.keys.first
        if !hash[current_key.to_sym].nil?
          new_hash[current_key] = return_specific_keys(hash[current_key.to_sym].symbolize_keys!, key[current_key])
        end
      end
    end
    return new_hash
  end
  
  def execute_on_table(time_range, &block)
    [time_range, time_range + 7.days].each do |time|
      table_name = Social::DynamoHelper.select_table(TABLE, time)
      yield(table_name, time) if block_given?
    end
  end
  
end
