module Facebook
  module Core 
    class Feed
      
      include Social::Util   
      include Facebook::Util
      include Facebook::Constants
      include Facebook::Exception::Handler
      
      attr_accessor :page_id, :realtime_feed, :sender_id, :fan_page
      
      #Initialize a facebook change object
      def initialize(page_id, entry_change)
        @page_id         = page_id
        @realtime_feed   = entry_change
      end
                 
      def process_feed(raw_obj)
        rl_measure = Benchmark.measure do
          select_shard_and_account(@fan_page.account_id) do |account|
            sandbox(raw_obj) do
              if perform_method && klass && can_process_feed?
                ("facebook/core/#{klass}").camelize.constantize.new(fan_page, feed_id).send(perform_method)
              end
            end
          end
        end
        custom_logger.info("Total time to process Page Id :: #{page_id} Feed Id :: #{feed_id} :: #{rl_measure.total}") unless custom_logger.nil?
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
        action = realtime_feed["value"]["verb"].downcase
        if ITEM_ACTIONS[action]
          ITEM_ACTIONS[action].include?(klass) ? action : nil
        else
          Rails.logger.debug("Invalid action verb from facebook : #{action}")
          nil
        end
      end
      
      #Returns one of the core classes - Post, Status, Comment, Reply to Comment
      def klass
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
      
      #Returns the value of the post_id, comment_id, sender_id and parent_id from the realtime feed
      ["post", "comment", "parent", "sender"].each do |object|
        define_method("#{object}_id") do
          @realtime_feed["value"]["#{object}_id"].to_s if @realtime_feed["value"]["#{object}_id"]
        end
      end         
      
      def feed_converted?
        Account.current.facebook_posts.exists?(:post_id => feed_id)
      end
      
      def feed_id
        comment_id || post_id
      end
      
      def by_visitor?   
        sender_id != @page_id   
      end
      
      def can_process_feed?
        !feed_converted?
      end 
      
      def custom_logger
        begin
          @@fb_logger ||= CustomLogger.new("#{Rails.root}/log/fb_benchmark.log")
        rescue Exception => e
          Rails.logger.info "Error occured while #{e}"
          NewRelic::Agent.notice_error(e, {:description => "Error while creating custom fb_logger"})
          nil
        end
      end
          
    end
  end
end
