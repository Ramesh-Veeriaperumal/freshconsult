module Social::Stream::Util
  
  include Social::Constants
  include Social::Util
  
  def build_current_interaction(current_feed_hash, search_type, convert_to_ticket)
    interactions_table = current_interactions_table
    interaction_results = []
    if (search_type == SEARCH_TYPE[:custom] || search_type == SEARCH_TYPE[:saved])
      hash_key = "#{current_feed_hash[:stream_id]}"
      schema   = TABLES["interactions"][:schema]
      results  = Social::DynamoHelper.get_item(interactions_table[:name], hash_key, "feed:#{current_feed_hash[:parent_feed_id]}", schema, nil )
      interaction_results << results[:item] if results[:item]
    end
    current_interaction  = process_results(interaction_results, current_feed_hash[:feed_id], convert_to_ticket)
    current_interaction.unshift(build_current_twitter_feed(current_feed_hash))  if (search_type == SEARCH_TYPE[:live] || search_type == SEARCH_TYPE[:custom])
    populate_fd_info_twitter(current_interaction, search_type)
    current_interaction
  end
  
  def process_results(interaction_results, current_feed_id, convert_to_ticket)
    feeds = []
    unless interaction_results.blank?
      interaction_hash = {}
      interaction_results.each do |stream_interaction|
        stream_id = stream_interaction['stream_id']
        feed_ids = stream_interaction['feed_ids']
        interaction_hash[stream_id] = convert_to_ticket ? feed_ids.select{ |feed_id| feed_id >= current_feed_id } : feed_ids
      end
      feeds_table_keys = interaction_hash.inject([]) do |arr, (key, value)|
        arr << batch_get_feeds_params(key, value)
        arr
      end

      feeds_table = {
        :name => Social::DynamoHelper.select_table("feeds", Time.now),
        :keys => feeds_table_keys.flatten
      }
      feeds_responses = Social::DynamoHelper.batch_get(feeds_table)
      feeds = feeds_responses.map{|result| result[:responses]["#{feeds_table[:name]}"] }.flatten
    end
    interactions = build_stream_feed_objects(feeds)
    sorted_interactions = Social::Stream::Feed.sort(interactions, :asc)
  end
  
  def batch_get_feeds_params(stream_id, feed_ids)
    feeds_table_keys = feed_ids.inject([]) do |arr, feed_id|
      arr << {
        'stream_id' => stream_id,
        'feed_id' => feed_id
      }
      arr
    end
  end
  
  def build_current_twitter_feed(current_feed_hash)
    tweet = Account.current.tweets.find_by_tweet_id(current_feed_hash[:feed_id])
    link = helpdesk_ticket_link(tweet.get_ticket) if tweet
    screen_names = current_feed_hash[:user_mentions].split(",")
    screen_names_hash = screen_names.map {|mention| {:screen_name => mention} }
    live_feed = {
      :text => current_feed_hash[:body],
      :user => {
        :name              => current_feed_hash[:name],
        :screen_name       => current_feed_hash[:screen_name],
        :profile_image_url => current_feed_hash[:image],
        :id_str            => current_feed_hash[:user_id]
      },
      :id_str     => current_feed_hash[:feed_id],
      :created_at => current_feed_hash[:posted_time],
      :ticket_id  => link,
      :stream_id  => current_feed_hash[:stream_id],
      :in_reply_to_status_id_str => current_feed_hash[:in_reply_to],
      :entities => {
        :user_mentions => screen_names_hash
      }
    }
    feed_obj = Social::Twitter::Feed.new(live_feed)
  end

  def current_interactions_table
    { :name => Social::DynamoHelper.select_table("interactions", Time.now) }
  end

  def build_stream_feed_objects(feeds)
    feed_objects = feeds.inject([]) do |arr, feed| 
      feed.symbolize_keys!
      arr << Social::Stream::TwitterFeed.new(feed) if feed[:source] && feed[:source] == SOURCE[:twitter]
      arr
    end
  end
end
