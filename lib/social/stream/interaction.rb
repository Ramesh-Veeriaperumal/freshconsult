module Social::Stream::Interaction

  include Social::Constants
  include Social::Util
  include Social::Stream::Util

  def pull_interactions(current_feed_hash, search_type)
    visible_stream_ids = fetch_visible_stream_ids
    interactions = {}
    unless visible_stream_ids.blank?
      current_interactions = build_current_interaction(current_feed_hash, search_type, false)
      user_interactions    = build_user_interactions(current_feed_hash[:user_id], visible_stream_ids, current_interactions_table, search_type)
      other_interactions   = user_interactions - current_interactions
      sorted_other_interactions = Social::Stream::Feed.sort(other_interactions, :desc)
      interactions[:current] = current_interactions
      interactions[:others] = sorted_other_interactions
    else
      interactions[:current] = [build_current_twitter_feed(current_feed_hash)]
    end
    interactions
  end

  def pull_user_interactions(user_hash, brand_stream_ids, search_type)
    interactions = build_user_interactions(user_hash[:id], brand_stream_ids, current_interactions_table, search_type)
    sorted_other_interactions = Social::Stream::Feed.sort(interactions, :desc)
    interactions = {
      :others => sorted_other_interactions
    }
  end

  private

  def build_user_interactions(user_id, visible_stream_ids, interactions_table, search_type)
    all_interactions = []
    begin
      interactions_table[:keys] = batch_get_interaction_params("user:#{user_id}", visible_stream_ids)
      results = Social::DynamoHelper.batch_get(interactions_table)
      interaction_results = results.map {|result| result[:responses][interactions_table[:name]]}.flatten
      interactions =  process_results(interaction_results, nil,false)
      all_interactions = interactions.select{ |feed| feed.ticket_id.blank? }
    rescue Aws::DynamoDB::Errors::ValidationException => e
      Rails.logger.error("Exception occurred while building social user interactions #{e.inspect}")
      error_params = {
        :account_id => Account.current.id,
        :stream_id => visible_stream_ids,
        :user_id => user_id
      }
      notify_social_dev("Validation exception in building user interactions", error_params)
    end
    all_interactions
  end

  def batch_get_interaction_params(user_id, streams_ids)
    interaction_table_keys =  streams_ids.inject([]) do |arr, stream_id|
      arr << {
        'stream_id' => "#{Account.current.id}_#{stream_id}",
        'object_id' => user_id.to_s
      }
      arr
    end
  end

  def fetch_visible_stream_ids
    User.current.visible_twitter_streams.collect(&:id)
  end

end
