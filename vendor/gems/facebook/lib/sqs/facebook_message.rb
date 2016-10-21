module Sqs
  class FacebookMessage
    
    include Sqs::Constants    
    include Social::Dynamo::UnprocessedFeed
    include Social::Util

    attr_accessor :page_id, :raw_obj, :entry, :messages_feed , :messages 

    def initialize(messages)
      @raw_obj = messages
      @messages_feed = JSON.parse(messages)
      unless @messages_feed.blank?
        @entry = @messages_feed["entry"]
        unless @entry.blank?
          @messages = @entry["messaging"].kind_of?(Array) ? @entry["messaging"] : ( @entry["messaging"].nil? ? [] : [ @entry["messaging"] ] )
          @page_id = @entry["id"]
        end
      end
    rescue JSON::ParserError => e
      Rails.logger.error("Failed in parsing facebook realtime messages to json")
      NewRelic::Agent.notice_error(e,{:description => "Error while parsing facebook realtime messages to json"})
    end

    def process
      return if @page_id.nil?
      @messages.each do |message|
        fb_message = Facebook::Core::Message.new(page_id, message)
        validity = fb_message.account_and_page_validity
        if validity[:valid_account] && validity[:realtime_messaging] && validity[:import_dms]
          if validity[:valid_page]
            select_fb_shard_and_account(page_id) do |account|
              @account_id = account.id
            end
            if page_rate_limit_reached?(@account_id,page_id)
              Sqs::Message.new("{}").requeue(@raw_obj,{:delay_seconds => 900})
            else           
              fb_message.process(@raw_obj)
            end
          else
            insert_facebook_feed(page_id, (Time.now.utc.to_f*1000).to_i, @raw_obj) 
            Rails.logger.info("Pushing message back to Dynamo due to re-auth")
          end
        end
      end
    end

  end
end