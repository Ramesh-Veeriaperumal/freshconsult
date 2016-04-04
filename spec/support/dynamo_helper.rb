include Social::Constants

module DynamoHelper

  def dynamo_feed_for_tweet(handle, tweet_feed, present, account_id=nil, handle_id=nil)
    unless handle.nil?
      account_id = handle.account_id
      handle_id = handle.default_stream.nil? ? handle.id : handle.default_stream.id
    end

    hash_key = "#{account_id}_#{handle_id}"
    tweet_id = tweet_feed["id"].split(":").last
    user_id = tweet_feed["actor"]["id"].split(":").last #User who created the original ticket

    #Check feeds table
    table = "feeds"
    feed_entry = dynamodb_entry(table, hash_key, tweet_id, tweet_feed["postedTime"])
    if present
      result = false
      feed_entry.should_not be_nil
      feed_entry["data"][:ss].each do |twt|
        result ||= compare_intersecting_keys(tweet_feed, JSON.parse(twt))
      end
      result.should be_truthy
    else
      feed_entry.should be_nil
    end

    #Check interactions table
    result = false
    for i in 1..5
      table = "interactions"
      user_entry = dynamodb_entry(table, hash_key, "user:#{user_id}", tweet_feed["postedTime"])
      tweet_id = tweet_feed["id"].split(":").last
      unless user_entry.nil?
        user_entry_tweet_ids = user_entry["feed_ids"][:ss]
        result ||= user_entry_tweet_ids.include?(tweet_id)
      end
      break if result
      sleep 1 if !user_entry.nil?
    end

    if present
      result.should be_truthy
    else
      result.should be_falsey
    end
    
    [feed_entry, user_entry]
  end
  
  def dynamo_feeds_for_tweet(table, hash_key, range_key, postedTime) 
    dynamodb_entry(table, hash_key, range_key, postedTime)
  end

  def sample_dynamo_get_item_params
    {
      :item => 
          { 
            "stream_id" => {:s=>"#{@account.id}_#{@default_stream.id}"}, 
            "feed_ids"=>{:ss=>["140264973268266"]
          }, 
          "object_id" => {
            :s =>"feed:140264973268266"
            }
          }
    }
  end

  private
    def dynamodb_entry(table, hash_value, range_value, postedTime)
      
      hash_key = {
          :comparison_operator => "EQ",
          :attribute_value_list => [
            {'s' => hash_value}
          ]
      }
      range_key = {
          :comparison_operator => "EQ",
          :attribute_value_list => [
            {'s' => range_value}
          ]
      }
      time = Time.parse(postedTime)

      schema = TABLES[table][:schema] #
      properties = DYNAMO_DB_CONFIG[table] #Social::Twitter::Constants::
      name = Social::DynamoHelper.select_table(table, time)

      for i in 1..5
        result = Social::DynamoHelper.query(name, hash_key, range_key, schema, 1, false)
        unless result[:member].empty?
          return result[:member].first
        else
          sleep 1
        end
      end

      return nil
    end

    def compare_intersecting_keys(a, b)
      (a.keys & b.keys).all? {|k| a[k] == b[k]}
    end

end
