module Facebook
  module Core
    class Post
          
      include Social::Constants
      
      include Facebook::Util
      include Facebook::Constants
      include Facebook::TicketActions::Util
      include Facebook::TicketActions::Post

      attr_accessor :fan_page, :account, :koala_post, :source, :type, :fd_item
      
      alias_attribute :koala_feed, :koala_post
      
      def initialize(fan_page, post_id, koala_post = nil)
        @fan_page      = fan_page
        @account       = Account.current
        @koala_post    = koala_post ? koala_post : get_koala_feed(POST_TYPE[:post], post_id)
        @source        = SOURCE[:facebook]
        @type          = POST_TYPE[:post]
        @fd_item       = helpdesk_item(@koala_post.feed_id)
      end

      # force_convert - Flag to decide if the post has to be converted to a ticket or not
      def process(force_convert = false)  
        if self.fd_item.nil? && (force_convert || convert_post_to_ticket?(self))
          self.fd_item = add_as_ticket(self.fan_page, self.koala_post, ticket_attributes)
        end        
        
        #Process comments only if post is converted to a ticket
        process_comments(self.fd_item) if self.fd_item.present?
      end

      alias :add :process
       
      private

      #Along with the post, comments of the respective comments are processed
      def process_comments(convert)
        self.koala_post.comments.each do |c|
          core_comment = Facebook::Core::Comment.new(self.fan_page, nil, get_koala_comment(c))
          core_comment.process(convert) 
        end
      end
     
    end
  end
end
