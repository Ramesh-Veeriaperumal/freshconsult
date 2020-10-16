module Sqs
  class FacebookMessage
    
    include Sqs::Constants    
    include Social::Dynamo::UnprocessedFeed
    include Social::Util
    include Facebook::RedisMethods

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
        fb_message = Facebook::Core::Message.new(page_id, message, @entry.try(:[], 'account_id'))
        validity = fb_message.account_and_page_validity
        return Rails.logger.debug "Invalid validity for page id: #{page_id}, account_id: #{@entry.try(:[], 'account_id')}, message: #{@entry.try(:[], 'messaging')}" if validity.nil? || !validity.is_a?(Hash)

        if validity[:valid_account] && validity[:realtime_messaging] && validity[:import_dms]
          if validity[:valid_page]
            set_account_id(page_id, @entry)
            if page_rate_limit_reached?(@account_id,page_id)
              Sqs::Message.new("{}").requeue(JSON.parse(@raw_obj),{:delay_seconds => 900})
            else           
              fb_message.process(@raw_obj)
            end
          else
            insert_facebook_feed(page_id, (Time.now.utc.to_f*1000).to_i, @raw_obj) 
            Rails.logger.info("Pushing message back to Dynamo due to re-auth")
          end
        else
          Rails.logger.debug "facebook message, invalid account, #{page_id}" unless validity[:valid_account]
        end
      end
    end

  end
end