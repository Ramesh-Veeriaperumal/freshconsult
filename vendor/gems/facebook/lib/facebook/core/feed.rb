module Facebook
  module Core 
    class Feed
      
      include Social::Util   
      
      include Facebook::Constants
      include Facebook::Exception::Handler
      
      attr_accessor :page_id, :realtime_feed, :sender_id, :fan_page, :dynamo_helper
      
      #Initialize a facebook change object
      def initialize(page_id, entry_change)
        @page_id         = page_id
        @realtime_feed   = entry_change
        @dynamo_helper   = Social::Dynamo::Facebook.new
      end
      
           
      def process_feed(raw_obj)
        select_shard_and_account(@fan_page.account_id) do |account|
          sandbox(raw_obj) do
            if (perform_method && klass)
              if AUXILLARY_LIST.include?(klass)
                ("facebook/core/#{klass}").camelize.constantize.new(fan_page, feed_id).send(perform_method) if social_revamp_enabled?
              elsif can_process_feed? 
                ("facebook/core/#{klass}").camelize.constantize.new(fan_page, feed_id).send(perform_method, convert_to_ticket?, dynamo_feed[:item].blank?)
              end
            end
          end
        end
      end
      
      def account_and_page_validity
        select_fb_shard_and_account(page_id) do |account|    
          if account.present? and account.active?
            @fan_page = account.facebook_pages.find_by_page_id(page_id)  
            [true, @fan_page.valid_page?]
          else
            [false, false]
          end
        end
      end

      private
      
      #Action performed on a feed - Add or Remove
      def perform_method
        return if realtime_feed["value"].blank?
        action = realtime_feed["value"]["verb"].downcase
        verb   = ITEM_ACTIONS[action].include?(klass) ? action : nil
      end
      
      #Returns one of the core classes - Post, Status, Comment, Reply to Comment
      def klass
        return if realtime_feed["value"].blank?
        item = realtime_feed["value"]["item"].downcase
        return unless ITEM_LIST.include?(item)
        
        case item
        when POST_TYPE[:photo], POST_TYPE[:video], POST_TYPE[:share]  
          by_visitor? ? POST_TYPE[:post] : POST_TYPE[:status] 
        when POST_TYPE[:comment]
          (post_id != parent_id) ? POST_TYPE[:reply_to_comment] : POST_TYPE[:comment]
        else #status and post
          item
        end
      end   
      
      #Checks if feed is already present in Dynamo
      #Checks if the feed is a comment and can be created to a ticket and is in Dynamo without a fd_link
      #Returns true if the feed is not in Dynamo or if it has to be converted to a ticket though it's  already pushed to Dynamo
      def can_process_feed?
        return !feed_converted? unless social_revamp_enabled?
        if dynamo_feed
          return true if dynamo_feed[:item].blank?
          visitor_comment? && fan_page.import_company_posts && !feed_converted?
        end
      end  
      
      #Returns the value of the post_id, comment_id, sender_id and parent_id from the realtime feed
      ["post", "comment", "parent", "sender"].each do |object|
        define_method("#{object}_id") do
          @realtime_feed["value"]["#{object}_id"].to_s if @realtime_feed["value"]["#{object}_id"]
        end
      end   
      
      #Returns true/false on either post? or status?
      ["post", "status"].each do |object|
        define_method("#{object}?") do
          klass == POST_TYPE[object.to_sym]
        end
      end
      
      def feed_converted?
        Account.current.facebook_posts.exists?(:post_id => feed_id)
      end

      def visitor_comment?
        comment? && by_visitor? 
      end
      
      def by_company?
        sender_id == @page_id
      end
      
      def by_visitor?
        sender_id != @page_id
      end
      
      def feed_id
        comment_id || post_id
      end
      
      def comment?
        POST_TYPE[:comment] || POST_TYPE[:reply_to_comment]
      end
      
      def convert_to_ticket?
        klass == POST_TYPE[:post] and self.fan_page.import_visitor_posts
      end
      
      def dynamo_feed
        return {} unless social_revamp_enabled?
        key   = dynamo_hash_and_range_key(fan_page.default_stream.id)
        @dynamo_feed ||= dynamo_helper.dynamo_feed(Time.now.utc, key, feed_id, false)
      end
          
    end
  end
end
