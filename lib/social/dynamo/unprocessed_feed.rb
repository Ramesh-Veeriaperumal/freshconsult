module Social
  module Dynamo
    module UnprocessedFeed
      
      include Social::Constants

      TABLE  = TABLE_NAME["unprocessed_feed"]
      SCHEMA = TABLES[TABLE][:schema]
      RECORDS_FETCH_LIMIT = 50
      
      def insert_facebook_feed(hash_key, range_key, feed)
        retention_period = TABLES[TABLE][:retention_period]
        times = [Time.now.utc, Time.now.utc + retention_period]
        feed_hash = JSON.parse(feed)
        if feed_hash["entry"] && feed_hash["entry"]["changes"].kind_of?(Array)
          item_hash  = facebook_feed_hash(hash_key, range_key, feed)
        elsif feed_hash["entry"] && feed_hash["entry"]["messaging"].kind_of?(Array)
          item_hash  = facebook_message_hash(hash_key, range_key, feed)
        end
        times.each do |time|
          table_name = Social::DynamoHelper.select_table(TABLE, time)
          Social::DynamoHelper.insert(table_name, item_hash, SCHEMA, false)
        end
      end
      
      def unprocessed_facebook_feeds(page_id)
        table_name = Social::DynamoHelper.select_table(TABLE, Time.now.utc)
        hash_key   = {
          comparison_operator: 'EQ',
          attribute_value_list: [page_id.to_s]
        }
        Social::DynamoHelper.query(table_name, hash_key, nil, SCHEMA, RECORDS_FETCH_LIMIT, true)
      end
      
      def delete_facebook_feed(data)
        item = {
          :hash_key   => data["page_id"][:n],
          :range_key  => data["timestamp"][:n]
        }
        retention_period = TABLES[TABLE][:retention_period]
        times = [Time.now.utc, Time.now.utc + retention_period]
        times.each do |time|
          table_name = Social::DynamoHelper.select_table(TABLE, time)
          Social::DynamoHelper.delete_item(table_name, item, SCHEMA)
        end
      end

      private

      def facebook_feed_hash(hash_key, range_key, feed)
        {
          'page_id' => hash_key.to_i,
          'timestamp' => range_key.to_i,
          'feed' => feed.to_s
        }
      end

      def facebook_message_hash(hash_key, range_key, message)
        {
          'page_id' => hash_key.to_i,
          'timestamp' => range_key.to_i,
          'message' => message.to_s
        }
      end
    end
  end
end
