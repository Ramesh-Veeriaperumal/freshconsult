class Social::Stream::Feed
  include Social::Constants
  include Gnip::Constants
  include Social::Twitter::Constants

  attr_accessor :stream_id, :feed_id, :posted_time, :is_replied, :user, :body, :dynamo_posted_time,
    :in_reply_to, :user_in_db, :in_conv, :agent_name, :ticket_id, :source, :parent_feed_id


  def hash
    stream_id.hash + 32*feed_id.hash
  end

  def eql?(other)
    other.stream_id == stream_id and other.feed_id == feed_id
  end

  def self.fetch(keys)
    results = Array.new
    threads = Array.new
    keys.each_with_index do |key, index|
      range_key = {
        :comparison_operator  => key[:operator],
        :attribute_value_list => [{
          's' => "#{key[:range_key]}"
        }]
      }
      hash_key = {
        :comparison_operator  => "EQ",
        :attribute_value_list => [{
          's' => "#{key[:hash_key]}"
        }]
      }
      results[index] = query(hash_key, range_key)
      
      # threads << Thread.new(key, index) { |key|
      #   range_key = {
      #     :comparison_operator  => key[:operator],
      #     :attribute_value_list => [{
      #       's' => "#{key[:range_key]}"
      #     }]
      #   }
      #   hash_key = {
      #     :comparison_operator  => "EQ",
      #     :attribute_value_list => [{
      #       's' => "#{key[:hash_key]}"
      #     }]
      #   }
      #   results[index] = query(hash_key, range_key)
      # }
      # threads.each {|thread| thread.join}
    end
    sorted_results = sort(results, :desc)
  end

  private

  def self.query(hash_key, range_key)
    # check for existence of table if not raise a notification
    table_name = Social::DynamoHelper.select_table("feeds", Time.now)
    schema     = TABLES["feeds"][:schema]
    limit      = NUM_RECORDS_TO_DISPLAY
    results = Social::DynamoHelper.query(table_name, hash_key, range_key, schema, limit, false)
    unless results.blank?
      stream_feeds = results.inject([]) do |arr, result_data|
        if result_data["source"] and result_data["source"][:s] == SOURCE[:twitter]
          arr << Social::Stream::TwitterFeed.new(result_data.symbolize_keys!)
        end
        arr
      end
    end
    stream_feeds
  end

  def self.sort(results, order)
    results = results.reject(&:blank?)
    results.flatten!
    sorted_results = results.sort_by { |result| result.dynamo_posted_time.to_i }
    order == :desc ? sorted_results.reverse! : sorted_results
  end

end
