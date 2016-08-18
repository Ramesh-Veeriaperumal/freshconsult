module Social
  module Dynamo
    module UnprocessedFeed
      
      include Social::Constants

      TABLE  = TABLE_NAME["unprocessed_feed"]
      SCHEMA = TABLES[TABLE][:schema]
      RECORDS_FETCH_LIMIT = 50
      
      def insert_facebook_feed(hash_key, range_key, feed)
        times = [Time.now.utc, Time.now.utc + 7.days]
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
          :comparison_operator  => "EQ",
          :attribute_value_list => [{
            :n => "#{page_id}"
          }]
        }
        Social::DynamoHelper.query(table_name, hash_key, nil, SCHEMA, RECORDS_FETCH_LIMIT, true)
      end
      
      def delete_facebook_feed(data)
        item = {
          :hash_key   => data["page_id"][:n],
          :range_key  => data["timestamp"][:n]
        }
        times = [Time.now.utc, Time.now.utc + 7.days]
        times.each do |time|
          table_name = Social::DynamoHelper.select_table(TABLE, time)
          Social::DynamoHelper.delete_item(table_name, item, SCHEMA)
        end
      end

      private
      
      def facebook_feed_hash(hash_key, range_key, feed)
        query_options = {
          "page_id" => {
            :n => "#{hash_key}"
          },
          "timestamp" => {
            :n => "#{range_key}"
          },
          "feed" => {
            :s => "#{feed}"
          }
        }
      end

      def facebook_message_hash(hash_key, range_key, message)
        query_options = {
          "page_id" => {
            :n => "#{hash_key}"
          },
          "timestamp" => {
            :n => "#{range_key}"
          },
          "message" => {
            :s => "#{message}"
          }
        }
      end
      
    end
  end
end
