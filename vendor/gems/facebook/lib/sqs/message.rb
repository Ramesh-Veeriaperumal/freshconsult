module Sqs
  class Message
    
    include Sqs::Constants    
    include Social::Dynamo::UnprocessedFeed
    include Facebook::RedisMethods
    include Social::Util
  
    attr_accessor :raw_obj, :feed, :entry, :entry_changes, :page_id

    #Initialize facebook feed of one page that has 1..n feed changes
    def initialize(feed)      
      @raw_obj = feed
      @feed    = JSON.parse(feed)
      unless @feed.blank?
        @entry   = @feed["entry"]
        unless @entry.blank?
          @page_id       = @entry["id"].to_s 
          @entry_changes = @entry["changes"] 
        end
      end
    rescue JSON::ParserError => e
      Rails.logger.error("Failed in parsing facebook feed to json")
      NewRelic::Agent.notice_error(e,{:description => "Error while parsing facebook feed to json"})
    end
    
    #Process all Facebook Feed Changes for a particular page
    def process
      entry_changes.each do |entry_change|
        fb_feed = Facebook::Core::Feed.new(page_id, entry_change, @entry.try(:[], 'account_id'))
        next if fb_feed.realtime_feed["value"].blank?
        @account_id = nil
        valid_account, valid_page = fb_feed.account_and_page_validity
        next unless valid_account
        if valid_page
          set_account_id(page_id, @entry)
          if page_rate_limit_reached?(@account_id,page_id)
            requeue(JSON.parse(raw_obj),{:delay_seconds => 900})
          else
            fb_feed.process_feed(raw_obj)
          end
        else
          #Insert feeds to the specifc Dynamo Tables if page need re-autorization
          insert_facebook_feed(page_id, (Time.now.utc.to_f*1000).to_i, @raw_obj) 
          Rails.logger.info("Pushing message back to Dynamo due to re-auth")
        end
      end
    end

    #Push Realtime Facebook Feed back to SQS from Dynamo on re-authorization
    def push(feeds, discard_feed)
      feeds.each do |data|
        unless discard_feed
          if data["feed"] && data["feed"][:s]
            $sqs_facebook.send_message(data["feed"][:s])
          elsif data["message"] && data["message"][:s]
            $sqs_facebook_messages.send_message(data["message"][:s])
          end
        end
        delete_facebook_feed(data)
      end
    end
  
    #Requeue Realtime Facebook Feed to SQS in case of rate limit with exponential delay 
    def requeue(msg, options={})
      if options[:delay_seconds].nil?
        msg["counter"] = msg["counter"].to_i + 1
        return false if msg["counter"] > FB_REQUEUE_COUNTER  #removing from the queue after 15 mins
        
        options[:delay_seconds] = msg["counter"] * FB_DELAY_SECONDS
      end
      if msg["entry"] && msg["entry"]["changes"].kind_of?(Array)
        Rails.logger.debug $sqs_facebook.send_message(msg.to_json, options)
      elsif msg["entry"] && msg["entry"]["messaging"].kind_of?(Array)
        Rails.logger.debug $sqs_facebook_messages.send_message(msg.to_json, options)
      end
    end
    
  end
end
