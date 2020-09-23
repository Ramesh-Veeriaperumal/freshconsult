module Facebook  
  module Core   
    class Comment
      
      include Social::Constants
      
      include Facebook::Util
      include Facebook::Constants
      include Facebook::TicketActions::Post
      include Facebook::TicketActions::Util
      
      attr_accessor :fan_page, :account, :koala_comment, :source, :type, :fd_item, :koala_post, 
                    :parent_fd_item

      alias_attribute :koala_feed, :koala_comment      

      def initialize(fan_page, comment_id, koala_comment = nil)
        @account        = Account.current
        @fan_page       = fan_page
        @koala_comment  = koala_comment ? koala_comment : get_koala_feed(POST_TYPE[:comment], comment_id)
        @koala_post     = Facebook::KoalaWrapper::Post.new(fan_page)
        @source         = SOURCE[:facebook]
        @type           = POST_TYPE[:comment]
        @fd_item        = helpdesk_item(@koala_comment.feed_id)
        @parent_fd_item = nil
      end   
      

      def process(force_convert = false, convert_company_comment_to_ticket = false, cover_photo_comment = false)
        #Comment is not converted to a fd_item as yet
        if self.fd_item.nil?
          #Comment can be added as a note
          if add_as_note?(force_convert) && check_filter_mention_tags?(self)
            self.fd_item = add_as_note(parent_post.postable, self.koala_comment) 
            process_reply_to_comments(self.fd_item) if self.fd_item   
          #Case to convert a post to a ticket via a comment happens only when it's a visitor comment  
          elsif convert_post_to_ticket?(self, true)
            process_post
          # When a comment is added on a cover photo and is not by the company
          elsif convert_cover_photo_comment_to_ticket?(self)
            self.fd_item = add_as_ticket(self.fan_page, self.koala_comment, ticket_attributes, self.koala_post)
          elsif convert_comment_to_ticket?(self, convert_company_comment_to_ticket) && !cover_photo_comment
            # This gets the root parent post.
            original_post = get_koala_feed(POST_TYPE[:post], post_id)
            self.fd_item = add_as_ticket(self.fan_page, self.koala_comment, ticket_attributes, original_post)
            process_reply_to_comments(self.fd_item) if self.fd_item     
          end
        end 
      end
      
      alias :add :process
      
      def feed_id
        self.koala_comment.comment_id
      end
      
      def fetch_parent_data
        unless self.koala_post.post_id.present?
          self.fan_page.log_api_hits
          self.koala_post.fetch(post_id) 
        end
      end

      private             
      
      def add_as_note?(convert_comment)
        convert_comment.is_a?(Helpdesk::Ticket) ? true : parent_post.present?
      end
      
      def process_post
        post_type  = self.koala_post.by_company? ? POST_TYPE[:status] : POST_TYPE[:post]
        
        ("facebook/core/#{post_type}").camelize.constantize.new(self.fan_page, post_id, self.koala_post).process(true)
      end

      def process_reply_to_comments(convert)
        self.koala_comment.comments.each do |c|
          reply_to_comment = Facebook::Core::ReplyToComment.new(self.fan_page, nil, get_koala_comment(c))
          reply_to_comment.process(convert)
        end
      end     
      
      def parent_post
        self.parent_fd_item ||= fd_post_obj(self.koala_comment.parent_post_id)
      end
      
      def post_id
        self.koala_comment.parent_post_id
      end
    end    
  end  
end
