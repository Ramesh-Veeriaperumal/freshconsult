module Social::Twitter::DynamoUtil
  include Social::Twitter::Constants
  include Social::Constants
  include Gnip::Constants

  def update_reply(stream_id, reply_params)
    tweet_hash = {
      :body => "#{reply_params[:body]}",
      :id => "tweet:#{reply_params[:id]}"
    }
    user_id = reply_params[:in_reply_to_user_id]
    in_reply_to = reply_params[:in_reply_to_id]
    posted_time = Time.parse(reply_params[:posted_at])

    items = {
      "conversations" => conversations_hash(stream_id, user_id, tweet_hash),
      "feeds" => feeds_hash(stream_id, in_reply_to, "", 1, {})
    }

    TABLES.keys.each do |table|      
      times = [posted_time, posted_time + 7.days]
      times.each do |time|
        table_name = Social::DynamoHelper.select_table(table, time)
        item_hash = items[table]
        Social::DynamoHelper.update(table_name, item_hash, TABLES[table][:schema])
      end
    end
  end

  def update_dm(stream_id, dm_params)
    table = "conversations"
    tweet_hash = {
      :body => "#{dm_params[:body]}",
      :id => "#{dm_params[:id]}"
    }
    user_id = dm_params[:user_id]
    posted_time = Time.parse(dm_params[:posted_at])

    item_hash = conversations_hash(stream_id, user_id, tweet_hash)

    times = [posted_time, posted_time + 7.days]
    times.each do |time|
      table_name = Social::DynamoHelper.select_table(table, time)
      if Social::DynamoHelper.table_validity(table, table_name, Time.now)
        Social::DynamoHelper.insert(table_name, item_hash, TABLES[table][:schema])
      end
    end
  end

  def update_tweet(args, attributes)
    id = args[:stream_id]
    stream_id = id.starts_with?(TAG_PREFIX) ? id.gsub(TAG_PREFIX, "") : id
    
    posted_time = Time.parse(@posted_time)
    attributes.merge!(:posted_time => "#{(posted_time.to_f * 1000).to_i}")

    TABLES.keys.each do |table|
      times = [posted_time, posted_time + 7.days]
      times.each do |time|
        table_name = Social::DynamoHelper.select_table(table, time)
        key = "#{args[:account_id]}_#{stream_id}"
        range = table.eql?("feeds") ? @tweet_id : @twitter_user_id
        tweet_hash = return_specific_keys(@tweet_obj, DYNAMO_KEYS[table])
        item_hash = send("#{table}_hash", key, range, tweet_hash, 0, attributes)
        Social::DynamoHelper.insert(table_name, item_hash, TABLES[table][:schema])
      end
    end
  end

  private
  
    def feeds_hash(hash, range, data, reply, attributes)
      item = {
        "stream_id" => {
          :s => "#{hash}"
        },
        "feed_id" => {
          :s => "#{range}"
        },
        "reply" => {
          :n => "#{reply}"
        },
        "source" => {
          :s => SOURCE[:twitter]
        }
      }

      if data.is_a?(Hash)
        item.merge!("data" => {
          :ss => [data.to_json]
        })
      end
      
      attributes.each do |key, value|
        item.merge!(key.to_s =>{:ss => [value.to_s]}) unless value.blank?
      end
      
      return item
    end

    def conversations_hash(hash, range, data, reply=0, fd_hash = {})
      {
        "stream_id" => {
          :s => "#{hash}"
        },
        "user_id" => {
          :s => "#{range}"
        },
        "data" => {
          :ss => [data.to_json]
        }
      }
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

end
