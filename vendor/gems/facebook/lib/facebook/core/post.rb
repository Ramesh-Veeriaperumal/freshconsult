module Facebook
  module Core
    class Post
          
      include Social::Constants
      
      include Facebook::Util
      include Facebook::Constants
      include Facebook::TicketActions::Util
      include Facebook::TicketActions::Post

      attr_accessor :fan_page, :account, :koala_post, :source, :type, :fd_item, :dynamo_helper
      
      alias_attribute :koala_feed, :koala_post
      
      def initialize(fan_page, post_id, koala_post = nil)
        @fan_page      = fan_page
        @account       = Account.current
        @koala_post    = koala_post ? koala_post : get_koala_feed(POST_TYPE[:post], post_id)
        @source        = SOURCE[:facebook]
        @type          = POST_TYPE[:post]
        @fd_item       = helpdesk_item(@koala_post.feed_id)
        @dynamo_helper = Social::Dynamo::Facebook.new
      end

      # convert_to_ticket - Flag to decide if the post has to be converted to a ticket or not
      # can_dynamo_push   - Flag to decide if the post has to be converted to a ticket or not
      # can_dynamo_push   - Set to false while processing posts already in Dynamo but yet to be converted into a ticket
      def process(convert_to_ticket, can_dynamo_push = true)   
        if self.fd_item.nil? && convert_to_ticket
          self.fd_item = add_as_ticket(self.fan_page, self.koala_post, ticket_attributes)
        end        
        
        #Insert post to Dynamo
        insert_post_in_dynamo if can_dynamo_push
        
        #Process comments only either if it has to be converted to a ticket or pushed to Dynamo
        process_comments(convert_to_ticket, can_dynamo_push) if (convert_to_ticket || can_dynamo_push)
        
        #Case happens when process post is called from the child classes
        #Status is in Dynamo but converted to a ticket later because of a visitor comment
        if (convert_to_ticket && !can_dynamo_push)
          dynamo_helper.update_ticket_links_in_dynamo(self.koala_post.post_id, self.fan_page.default_stream.id) 
        end
      end

      alias :add :process

      def feed_hash
        self.koala_post.instance_values.symbolize_keys
      end
       
      def insert_post_in_dynamo
        dynamo_helper.insert_post_in_dynamo(self) 
      end
       
      private

      #Along with the post, comments of the respective comments are processed
      def process_comments(convert, can_dynamo_push)
        self.koala_post.comments.each do |c|
          core_comment = Facebook::Core::Comment.new(self.fan_page, nil, get_koala_comment(c))
          core_comment.process(convert, can_dynamo_push, true) 
        end
      end

      def ticket_attributes    
        {
          :group_id   => @fan_page.group_id,
          :product_id => @fan_page.product_id
        }
      end       
    end
  end
end
