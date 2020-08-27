module Facebook
  module Core
    class ReplyToComment < Comment
      
      def initialize(fan_page, comment_id, koala_comment = nil)
        super(fan_page, comment_id, koala_comment)
        @type = POST_TYPE[:reply_to_comment]
      end  
      

      def process(force_convert = false)
        #Reply is not converted to a note as yet
        if self.fd_item.nil?
          fb_post    = fd_post_obj(self.koala_comment.parent_post_id) 
          fb_comment = fd_post_obj(in_reply_to) if self.koala_comment.parent
          
          #Parent comment is an fd_item
          if fb_comment
            #Parent Comment is a ticket
            self.fd_item = add_as_note(fb_comment.postable, koala_comment) if fb_comment.is_ticket? && check_filter_mention_tags?(self)
            #Parent Comment is a note
            self.fd_item = add_as_note(fb_post.postable, koala_comment) if (fb_comment.is_note? && check_filter_mention_tags?(self))
            
          #Parent Post is converted to a ticket, but the parent comment is not added as a note (edge case)
          elsif fb_post
            fetch_and_process_comment(fb_post)
          #Case to convert a post to a ticket via a comment happens only when it's a visitor comment  
          elsif convert_post_to_ticket?(self, true)
            process_post
          else
            # Convert the parent comments as a ticket(Even if it is a company comment) and add this reply as a note to that ticket.
            fetch_and_process_comment(nil, true)
          end
        end
        
      end        
      
      alias :add :process     

      def in_reply_to
        self.koala_comment.parent[:id] if koala_comment.parent
      end
      
      private 
      
      # Condition 1: Post is a ticket but the parent comment is not converted to a note.
      # Condition 2: Post, Comment hasn't yet got converted to a ticket.
      # => Optimal: Comment to this reply to comment will be added as a ticket.
      # => Broad: Will be created as a single ticket.
      def fetch_and_process_comment(fb_post = nil, convert_company_comment_to_ticket = false)
        #Explicitly logging second call made within the exception handler
        # in_reply_to will be nil for comment on a cover photo. Facebook gives us different IDs for post_id and parent_id
        # for a comment on the cover photo.
        self.fan_page.log_api_hits
        if in_reply_to.nil?
          Facebook::Core::Comment.new(fan_page, self.koala_comment.feed_id).process(fb_post.try(:postable), false, true)
        else
          Facebook::Core::Comment.new(fan_page, in_reply_to).process(fb_post.try(:postable), convert_company_comment_to_ticket)
        end
      end
      
    end
  end
end
