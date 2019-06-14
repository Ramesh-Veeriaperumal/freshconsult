class Social::SmartFilterFeedbackWorker < BaseWorker
 
  include Social::Constants
  include Social::DynamoHelper
  include Social::SmartFilter
  include Social::Util

  sidekiq_options queue: :smart_filter_feedback,
                  retry: 3,
                  failures: :exhausted
  
  def perform(args)   
    args.symbolize_keys!
    @account = Account.current
    @ticket = @account.tickets.find_by_id args[:ticket_id]
    @twitter_handle = @ticket.tweet.twitter_handle
    @dynamo_helper = Social::Dynamo::Twitter.new

    if should_give_feedback_to_smart_filter?(args[:type_of_feedback])
      begin
        response = smart_filter_feedback(generate_feedback_request_body(args[:type_of_feedback]))
        record_smart_filter_feedback
      rescue Exception => e
        handle_failure(e, args)
      end 
    end
  end

  def handle_failure(response, args) 
    notify_social_dev("Error sending feedback to smart filter", {:msg => "Account_ID: #{Account.current.id} Params: #{args} :: Response code: #{response}"})
    unless response.is_a?(RestClient::Exception) && response.http_code.between?(400, 499)
      raise "Error sending feedback to smart filter: Account_ID: #{Account.current.id}"
    end
  end

  def should_give_feedback_to_smart_filter?(type_of_feedback)
    if @account.twitter_smart_filter_enabled? && @twitter_handle && ticket_created_from_default_stream? 
      if type_of_feedback == SMART_FILTER_FEEDBACK_TYPE[:spam]
        tweet_predicted_as_ticket_by_smart_filter?
      else
        tweet_predicted_as_spam_by_smart_filter?
      end
    end
  end

  def tweet_predicted_as_ticket_by_smart_filter?
    result = tweet_info_from_dynamo
    result["smart_filter_response"] && result["smart_filter_response"][:n].to_i == SMART_FILTER_DETECTED_AS_TICKET 
  end

  def tweet_predicted_as_spam_by_smart_filter?
    result = tweet_info_from_dynamo
    result["smart_filter_response"] && result["smart_filter_response"][:n].to_i == SMART_FILTER_DETECTED_AS_SPAM
  end

  def ticket_created_from_default_stream?
    @ticket.tweet.stream && @ticket.tweet.stream.default_stream?
  end

  def tweet_info_from_dynamo
    @dynamo_helper.fetch_feed_info_from_dynamo({:account_id => @account.id, :stream_id => @ticket.tweet.stream_id, :feed_id => @ticket.tweet.tweet_id, :attributes => ["smart_filter_response"]})
  end

  def record_smart_filter_feedback
    @dynamo_helper.record_smart_filter_feedback_given_in_dynamo({:account_id => @account.id, :stream_id => @ticket.tweet.stream_id, :feed_id => @ticket.tweet.tweet_id})
  end

   def generate_feedback_request_body(type_of_feedback)
    {
      :entity_id => smart_filter_enitytID(:twitter,@account.id,@ticket.tweet.tweet_id),
      :account_id => smart_filter_accountID(:twitter, @account.id, @twitter_handle.twitter_user_id),
      :text => @ticket.subject,
      :screen_name => [],
      :source => "twitter",
      :type_of_feedback => type_of_feedback,
      :lang => "en"
   }.to_json
  end
end